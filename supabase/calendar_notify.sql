-- Cofradero · avisos de calendario para usuarios finales
-- Ejecutar después de:
--   - schema.sql
--   - notification_social.sql
--   - calendar_events.sql
--   - roles_v2.sql (si usas estados published/pending_review/rejected)
--   - reply_reaction_notify.sql (o al menos la columna notify_reactions)

alter table public.notification_preferences
  add column if not exists notify_reactions boolean not null default true;

-- Amplía el helper de preferencias para soportar notify_calendar.
create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'calendar' then coalesce(
      (select notify_calendar from public.notification_preferences where user_id = p_user_id),
      false
    )
    else true
  end;
$$;

create or replace function public.notify_users_on_calendar_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  if new.status <> 'published' then
    return new;
  end if;

  -- Evita duplicar avisos si el evento ya estaba publicado.
  if tg_op = 'UPDATE' and coalesce(old.status, '') = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  v_title := case new.event_type
    when 'procesion' then 'Nueva procesión en el calendario'
    when 'gloria' then 'Nuevo acto de gloria'
    when 'ensayo' then 'Nuevo ensayo en el calendario'
    when 'iguala' then 'Nueva igualá en el calendario'
    when 'concierto' then 'Nuevo concierto cofrade'
    else 'Nuevo aviso del calendario'
  end;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    p.id,
    'calendar',
    v_title,
    left(new.title, 80),
    jsonb_build_object(
      'route', '/calendario',
      'eventId', new.id::text,
      'eventType', new.event_type,
      'startsAt', new.starts_at,
      'organizerLabel', new.organizer_label
    )
  from public.profiles p
  where p.suspended_at is null
    and p.id is distinct from new.created_by
    and public.notify_pref_enabled(p.id, 'calendar');

  return new;
end;
$$;

drop trigger if exists on_calendar_published_notify_users on public.calendar_events;
create trigger on_calendar_published_notify_users
  after insert or update of status on public.calendar_events
  for each row execute function public.notify_users_on_calendar_published();
