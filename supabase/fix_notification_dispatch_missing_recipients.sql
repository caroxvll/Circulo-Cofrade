-- Cofradeo · Fix: fan-out a veces marca el job "done" sin dejar notificación a todos.
-- Ejecutar en Supabase → SQL Editor.
--
-- 1) Repara jobs "done" con seguidores elegibles sin notificación (p.ej. @paco).
-- 2) Endurece process_notification_dispatch (candidatos materializados).

-- =============================================================================
-- 1) Reparar destinatarios faltantes de un job (o de los últimos done)
-- =============================================================================
create or replace function public.repair_notification_dispatch_job(p_job_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.notification_dispatch_jobs%rowtype;
  v_payload jsonb;
  inserted int := 0;
begin
  if auth.uid() is not null and not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  perform set_config('row_security', 'off', true);

  select * into job
  from public.notification_dispatch_jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'Job no encontrado';
  end if;

  if coalesce(job.audience_mode, 'follows') <> 'follows'
     or coalesce(job.audience_target_type, '') <> 'topic' then
    return jsonb_build_object(
      'ok', false,
      'reason', 'solo repara jobs follows/topic',
      'jobId', p_job_id
    );
  end if;

  v_payload := coalesce(job.payload, '{}'::jsonb);
  if job.dedupe_key is not null then
    v_payload := v_payload || jsonb_build_object('dedupeKey', job.dedupe_key);
  end if;

  with missing as (
    select f.follower_id
    from public.follows f
    join public.profiles p on p.id = f.follower_id
    where f.target_type = job.audience_target_type
      and f.target_id = job.audience_target_id
      and p.suspended_at is null
      and f.follower_id is distinct from job.author_id
      and (
        job.audience_pref is null
        or public.notify_pref_enabled(f.follower_id, job.audience_pref)
      )
      and (
        job.author_id is null
        or public.is_not_blocked(f.follower_id, job.author_id)
      )
      and (
        job.audience_official_category is null
        or f.notify_official_categories is null
        or job.audience_official_category = any (f.notify_official_categories)
      )
      and not exists (
        select 1
        from public.notifications n
        where n.user_id = f.follower_id
          and n.type = job.notif_type
          and (
            (job.dedupe_key is not null and n.payload->>'dedupeKey' = job.dedupe_key)
            or (
              job.dedupe_key is null
              and n.payload->>'replyId' = coalesce(job.payload->>'replyId', job.source_id)
            )
          )
      )
  ),
  inserted_rows as (
    insert into public.notifications (user_id, type, title, subtitle, payload)
    select
      m.follower_id,
      job.notif_type,
      job.title,
      job.subtitle,
      v_payload
    from missing m
    returning user_id
  )
  select count(*)::int into inserted from inserted_rows;

  if inserted > 0 then
    update public.notification_dispatch_jobs
    set
      processed_count = processed_count + inserted,
      updated_at = now(),
      error_message = null
    where id = job.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'jobId', p_job_id,
    'inserted', inserted
  );
end;
$$;

create or replace function public.repair_recent_hermandad_dispatch_jobs(
  p_hours int default 48
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  total int := 0;
  one jsonb;
  details jsonb := '[]'::jsonb;
begin
  if auth.uid() is not null and not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  perform set_config('row_security', 'off', true);

  for r in
    select id
    from public.notification_dispatch_jobs
    where kind = 'topic_followers'
      and audience_target_type = 'topic'
      and status = 'done'
      and created_at > now() - make_interval(hours => greatest(coalesce(p_hours, 48), 1))
    order by created_at desc
    limit 40
  loop
    one := public.repair_notification_dispatch_job(r.id);
    total := total + coalesce((one->>'inserted')::int, 0);
    details := details || jsonb_build_array(one);
  end loop;

  return jsonb_build_object('ok', true, 'insertedTotal', total, 'jobs', details);
end;
$$;

revoke all on function public.repair_notification_dispatch_job(uuid) from public;
revoke all on function public.repair_recent_hermandad_dispatch_jobs(int) from public;
grant execute on function public.repair_notification_dispatch_job(uuid) to authenticated;
grant execute on function public.repair_recent_hermandad_dispatch_jobs(int) to authenticated;

-- =============================================================================
-- 2) Procesador endurecido (candidates materializados + cursor desde insertados)
-- =============================================================================
create or replace function public.process_notification_dispatch(p_limit int default 500)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.notification_dispatch_jobs%rowtype;
  batch_limit int := least(greatest(coalesce(p_limit, 500), 50), 2000);
  inserted int := 0;
  last_created timestamptz;
  last_follower uuid;
  v_payload jsonb;
begin
  perform set_config('row_security', 'off', true);
  perform public.reclaim_stale_notification_jobs();

  select * into job
  from public.notification_dispatch_jobs
  where status = 'pending'
     or (status = 'failed' and retry_count < 5)
  order by created_at
  for update skip locked
  limit 1;

  if not found then
    return jsonb_build_object('ok', true, 'processed', 0, 'reason', 'idle');
  end if;

  update public.notification_dispatch_jobs
  set status = 'processing', updated_at = now()
  where id = job.id;

  v_payload := coalesce(job.payload, '{}'::jsonb);
  if job.dedupe_key is not null then
    v_payload := v_payload || jsonb_build_object('dedupeKey', job.dedupe_key);
  end if;

  if job.audience_mode is null then
    job.audience_mode := 'follows';
  end if;
  if job.notif_type is null then
    job.notif_type := 'news_published';
  end if;
  if job.audience_target_type is null and job.kind = 'news_published' then
    job.audience_target_type := 'forum';
    job.audience_target_id := 'noticias';
    job.audience_pref := 'news';
  end if;

  create temporary table if not exists _notif_dispatch_batch (
    follower_id uuid primary key,
    follow_created_at timestamptz not null
  ) on commit drop;

  delete from _notif_dispatch_batch;

  if job.audience_mode = 'pref' then
    insert into _notif_dispatch_batch (follower_id, follow_created_at)
    select p.id, p.created_at
    from public.profiles p
    where p.suspended_at is null
      and p.id is distinct from job.author_id
      and public.notify_pref_enabled(p.id, coalesce(job.audience_pref, 'calendar'))
      and (
        job.cursor_follower_id is null
        or (p.created_at, p.id) > (job.cursor_created_at, job.cursor_follower_id)
      )
      and (
        job.dedupe_key is null
        or not exists (
          select 1 from public.notifications n
          where n.user_id = p.id
            and n.type = job.notif_type
            and n.payload->>'dedupeKey' = job.dedupe_key
        )
      )
    order by p.created_at, p.id
    limit batch_limit;

  elsif job.audience_mode = 'follows_hashtags' then
    insert into _notif_dispatch_batch (follower_id, follow_created_at)
    select x.follower_id, x.follow_created_at
    from (
      select f.follower_id, min(f.created_at) as follow_created_at
      from public.follows f
      join public.profiles p on p.id = f.follower_id
      where f.target_type = 'hashtag'
        and lower(f.target_id) = any (
          select lower(t) from unnest(coalesce(job.audience_hashtags, array[]::text[])) as t
        )
        and p.suspended_at is null
        and f.follower_id is distinct from job.author_id
        and public.notify_pref_enabled(f.follower_id, coalesce(job.audience_pref, 'hashtags'))
        and (
          job.author_id is null
          or public.is_not_blocked(f.follower_id, job.author_id)
        )
        and (
          job.cursor_follower_id is null
          or f.follower_id > job.cursor_follower_id
        )
        and (
          job.dedupe_key is null
          or not exists (
            select 1 from public.notifications n
            where n.user_id = f.follower_id
              and n.type = job.notif_type
              and n.payload->>'dedupeKey' = job.dedupe_key
          )
        )
      group by f.follower_id
    ) x
    order by x.follower_id
    limit batch_limit;

  else
    insert into _notif_dispatch_batch (follower_id, follow_created_at)
    select f.follower_id, f.created_at
    from public.follows f
    join public.profiles p on p.id = f.follower_id
    where f.target_type = coalesce(job.audience_target_type, 'forum')
      and f.target_id = coalesce(job.audience_target_id, 'noticias')
      and p.suspended_at is null
      and f.follower_id is distinct from job.author_id
      and (
        job.audience_pref is null
        or public.notify_pref_enabled(f.follower_id, job.audience_pref)
      )
      and (
        job.author_id is null
        or public.is_not_blocked(f.follower_id, job.author_id)
      )
      and (
        job.audience_official_category is null
        or f.notify_official_categories is null
        or job.audience_official_category = any (f.notify_official_categories)
      )
      and (
        job.cursor_created_at is null
        or (f.created_at, f.follower_id) > (job.cursor_created_at, job.cursor_follower_id)
      )
      and (
        job.dedupe_key is null
        or not exists (
          select 1 from public.notifications n
          where n.user_id = f.follower_id
            and n.type = job.notif_type
            and n.payload->>'dedupeKey' = job.dedupe_key
        )
      )
    order by f.created_at, f.follower_id
    limit batch_limit;
  end if;

  with inserted_rows as (
    insert into public.notifications (user_id, type, title, subtitle, payload)
    select b.follower_id, job.notif_type, job.title, job.subtitle, v_payload
    from _notif_dispatch_batch b
    returning user_id
  )
  select
    (select count(*)::int from inserted_rows),
    (
      select b.follow_created_at
      from _notif_dispatch_batch b
      join inserted_rows i on i.user_id = b.follower_id
      order by b.follow_created_at desc, b.follower_id desc
      limit 1
    ),
    (
      select b.follower_id
      from _notif_dispatch_batch b
      join inserted_rows i on i.user_id = b.follower_id
      order by b.follow_created_at desc, b.follower_id desc
      limit 1
    )
  into inserted, last_created, last_follower;

  if coalesce(inserted, 0) = 0 then
    update public.notification_dispatch_jobs
    set status = 'done', updated_at = now(), error_message = null
    where id = job.id;
    return jsonb_build_object('ok', true, 'jobId', job.id, 'processed', 0, 'status', 'done');
  end if;

  update public.notification_dispatch_jobs
  set
    cursor_created_at = last_created,
    cursor_follower_id = last_follower,
    processed_count = processed_count + inserted,
    updated_at = now(),
    status = case when inserted < batch_limit then 'done' else 'pending' end,
    error_message = null,
    retry_count = 0
  where id = job.id;

  return jsonb_build_object(
    'ok', true,
    'jobId', job.id,
    'processed', inserted,
    'status', case when inserted < batch_limit then 'done' else 'pending' end,
    'kind', job.kind
  );
exception
  when others then
    update public.notification_dispatch_jobs
    set
      retry_count = retry_count + 1,
      status = case when retry_count + 1 >= 5 then 'failed' else 'pending' end,
      error_message = left(sqlerrm, 400),
      updated_at = now()
    where id = job.id;
    return jsonb_build_object(
      'ok', false,
      'error', sqlerrm,
      'willRetry', true
    );
end;
$$;

revoke all on function public.process_notification_dispatch(int) from public;
grant execute on function public.process_notification_dispatch(int) to service_role;

-- =============================================================================
-- 3) Reparar ya los jobs recientes de hermandad (incluye el de Paco)
-- =============================================================================
select public.repair_recent_hermandad_dispatch_jobs(72);

notify pgrst, 'reload schema';
