-- Cofradeo · visión global de notificaciones / push (solo admin)
-- Ejecutar en Supabase SQL Editor.

-- ---------------------------------------------------------------------------
-- KPIs + volumen por tipo (últimos N días)
-- ---------------------------------------------------------------------------
create or replace function public.get_notifications_admin_overview(
  p_days int default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days int := greatest(1, least(coalesce(p_days, 30), 90));
  v_since timestamptz := now() - make_interval(days => v_days);
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  select jsonb_build_object(
    'days', v_days,
    'since', v_since,
    'totalUsers', (
      select count(*)::int from public.profiles
    ),
    'pushEnabledUsers', (
      select count(*)::int
      from public.notification_preferences
      where push_enabled = true
    ),
    'pushDisabledUsers', (
      select count(*)::int
      from public.profiles p
      left join public.notification_preferences np on np.user_id = p.id
      where coalesce(np.push_enabled, false) = false
    ),
    'pushOnWithDevice', (
      select count(*)::int
      from public.notification_preferences np
      where np.push_enabled = true
        and exists (
          select 1 from public.device_tokens dt where dt.user_id = np.user_id
        )
    ),
    'pushOnNoDevice', (
      select count(*)::int
      from public.notification_preferences np
      where np.push_enabled = true
        and not exists (
          select 1 from public.device_tokens dt where dt.user_id = np.user_id
        )
    ),
    'usersWithToken', (
      select count(distinct user_id)::int
      from public.device_tokens
    ),
    'tokenCount', (
      select count(*)::int
      from public.device_tokens
    ),
    'tokensByPlatform', coalesce((
      select jsonb_object_agg(platform, cnt)
      from (
        select coalesce(nullif(trim(platform), ''), 'unknown') as platform,
               count(*)::int as cnt
        from public.device_tokens
        group by 1
      ) t
    ), '{}'::jsonb),
    'notificationsTotal', (
      select count(*)::int
      from public.notifications
      where created_at >= v_since
    ),
    'byType', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'type', type,
          'count', cnt
        )
        order by cnt desc
      )
      from (
        select type, count(*)::int as cnt
        from public.notifications
        where created_at >= v_since
        group by type
      ) s
    ), '[]'::jsonb),
    'byDay', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'day', day,
          'count', cnt
        )
        order by day desc
      )
      from (
        select (created_at::date) as day,
               count(*)::int as cnt
        from public.notifications
        where created_at >= v_since
        group by 1
      ) d
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.get_notifications_admin_overview(int) to authenticated;

-- ---------------------------------------------------------------------------
-- Diagnóstico por usuario (prefs + tokens, sin FCM completo)
-- ---------------------------------------------------------------------------
create or replace function public.get_notifications_user_diag(
  p_handle text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_handle text := lower(trim(both from coalesce(p_handle, '')));
  v_profile record;
  v_prefs jsonb;
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  if v_handle = '' then
    raise exception 'Indica un handle';
  end if;

  if left(v_handle, 1) = '@' then
    v_handle := substr(v_handle, 2);
  end if;

  select id, handle, display_name, role
  into v_profile
  from public.profiles
  where lower(handle) = v_handle
  limit 1;

  if not found then
    return jsonb_build_object('found', false, 'handle', v_handle);
  end if;

  select to_jsonb(np) - 'user_id' - 'updated_at'
  into v_prefs
  from public.notification_preferences np
  where np.user_id = v_profile.id;

  select jsonb_build_object(
    'found', true,
    'userId', v_profile.id,
    'handle', v_profile.handle,
    'displayName', v_profile.display_name,
    'role', v_profile.role,
    'pushEnabled', coalesce((v_prefs ->> 'push_enabled')::boolean, false),
    'prefs', v_prefs,
    'tokens', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'platform', coalesce(nullif(trim(dt.platform), ''), 'unknown'),
          'tokenPreview', left(dt.fcm_token, 12) || '…',
          'updatedAt', dt.updated_at
        )
        order by dt.updated_at desc nulls last
      )
      from public.device_tokens dt
      where dt.user_id = v_profile.id
    ), '[]'::jsonb),
    'tokenCount', (
      select count(*)::int
      from public.device_tokens
      where user_id = v_profile.id
    ),
    'recentNotifications', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', n.id,
          'type', n.type,
          'title', n.title,
          'createdAt', n.created_at,
          'read', n.read_at is not null
        )
        order by n.created_at desc
      )
      from (
        select *
        from public.notifications
        where user_id = v_profile.id
        order by created_at desc
        limit 20
      ) n
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.get_notifications_user_diag(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Listado de usuarios por estado de push
-- p_filter: 'all' | 'on' | 'off' | 'on_no_token' | 'off_with_token'
-- ---------------------------------------------------------------------------
create or replace function public.list_push_users(
  p_filter text default 'all',
  p_search text default null,
  p_limit int default 100,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_filter text := lower(trim(coalesce(p_filter, 'all')));
  v_search text := lower(trim(both from coalesce(p_search, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 300));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  if left(v_search, 1) = '@' then
    v_search := substr(v_search, 2);
  end if;

  with base as (
    select
      p.id,
      p.handle,
      p.display_name,
      p.role,
      coalesce(np.push_enabled, false) as push_enabled,
      coalesce(tok.token_count, 0)::int as token_count,
      tok.platforms,
      case
        when np.user_id is null then null
        else to_jsonb(np) - 'user_id' - 'updated_at' - 'push_enabled'
      end as prefs
    from public.profiles p
    left join public.notification_preferences np on np.user_id = p.id
    left join lateral (
      select
        count(*)::int as token_count,
        string_agg(distinct coalesce(nullif(trim(dt.platform), ''), 'unknown'), ', ' order by coalesce(nullif(trim(dt.platform), ''), 'unknown')) as platforms
      from public.device_tokens dt
      where dt.user_id = p.id
    ) tok on true
    where (
      v_search = ''
      or lower(p.handle) like '%' || v_search || '%'
      or lower(coalesce(p.display_name, '')) like '%' || v_search || '%'
    )
    and (
      v_filter = 'all'
      or (v_filter = 'on' and coalesce(np.push_enabled, false) = true)
      or (v_filter = 'off' and coalesce(np.push_enabled, false) = false)
      or (
        v_filter = 'on_no_token'
        and coalesce(np.push_enabled, false) = true
        and coalesce(tok.token_count, 0) = 0
      )
      or (
        v_filter = 'off_with_token'
        and coalesce(np.push_enabled, false) = false
        and coalesce(tok.token_count, 0) > 0
      )
    )
  ),
  counted as (
    select count(*)::int as total from base
  ),
  page as (
    select *
    from base
    order by
      push_enabled desc,
      token_count desc,
      handle asc
    limit v_limit
    offset v_offset
  )
  select jsonb_build_object(
    'total', (select total from counted),
    'limit', v_limit,
    'offset', v_offset,
    'filter', v_filter,
    'rows', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'userId', page.id,
          'handle', page.handle,
          'displayName', page.display_name,
          'role', page.role,
          'pushEnabled', page.push_enabled,
          'tokenCount', page.token_count,
          'platforms', coalesce(page.platforms, ''),
          'prefs', page.prefs
        )
      )
      from page
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.list_push_users(text, text, int, int) to authenticated;
