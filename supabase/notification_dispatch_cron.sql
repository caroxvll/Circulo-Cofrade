-- Cofradero · Cola de notificaciones: reintentos solos + Cron automático
-- Ejecutar DESPUÉS de scale_hardening_v1.sql y scale_hardening_v2.sql.
--
-- Esto arregla dos cosas:
-- 1) Un lote fallido se reintenta SOLO (hasta 5 veces). No tienes que “reprocesar a mano”.
-- 2) El Cron se programa UNA vez aquí y ya corre solo cada minuto.
--
-- Requisitos: Dashboard → Database → Extensions → activar **pg_cron**

-- =============================================================================
-- 1) Reintentos automáticos
-- =============================================================================
alter table public.notification_dispatch_jobs
  add column if not exists retry_count int not null default 0;

-- Si un job se quedó “processing” (corte, timeout), vuelve a pending solo.
create or replace function public.reclaim_stale_notification_jobs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  update public.notification_dispatch_jobs
  set
    status = 'pending',
    updated_at = now(),
    error_message = left(coalesce(error_message, '') || ' · reclaimed stale', 400)
  where status = 'processing'
    and updated_at < now() - interval '5 minutes';
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Sustituye el procesador: incluye failed con reintentos y no se queda muerto.
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

  -- Defaults por si el job es de v1 (solo noticias)
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

  if job.audience_mode = 'pref' then
    with candidates as (
      select p.id as follower_id, p.created_at as follow_created_at
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
      limit batch_limit
    ),
    inserted_rows as (
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select c.follower_id, job.notif_type, job.title, job.subtitle, v_payload
      from candidates c
      returning 1
    )
    select
      (select count(*)::int from inserted_rows),
      (select follow_created_at from candidates order by follow_created_at desc, follower_id desc limit 1),
      (select follower_id from candidates order by follow_created_at desc, follower_id desc limit 1)
    into inserted, last_created, last_follower;

  elsif job.audience_mode = 'follows_hashtags' then
    with candidates as (
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
      limit batch_limit
    ),
    inserted_rows as (
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select c.follower_id, job.notif_type, job.title, job.subtitle, v_payload
      from candidates c
      returning 1
    )
    select
      (select count(*)::int from inserted_rows),
      (select follow_created_at from candidates order by follower_id desc limit 1),
      (select follower_id from candidates order by follower_id desc limit 1)
    into inserted, last_created, last_follower;

  else
    with candidates as (
      select f.follower_id, f.created_at as follow_created_at
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
      limit batch_limit
    ),
    inserted_rows as (
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select c.follower_id, job.notif_type, job.title, job.subtitle, v_payload
      from candidates c
      returning 1
    )
    select
      (select count(*)::int from inserted_rows),
      (select follow_created_at from candidates order by follow_created_at desc, follower_id desc limit 1),
      (select follower_id from candidates order by follow_created_at desc, follower_id desc limit 1)
    into inserted, last_created, last_follower;
  end if;

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
    -- Reintento solo: vuelve a pending (hasta 5 fallos seguidos).
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

-- Un “tick” del Cron: procesa varios lotes seguidos si hay cola.
create or replace function public.process_notification_dispatch_tick(
  p_limit int default 500,
  p_max_jobs int default 8
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  i int;
  total int := 0;
  result jsonb;
  max_jobs int := least(greatest(coalesce(p_max_jobs, 8), 1), 20);
begin
  for i in 1..max_jobs loop
    result := public.process_notification_dispatch(p_limit);
    total := total + coalesce((result->>'processed')::int, 0);
    exit when coalesce(result->>'reason', '') = 'idle';
    exit when coalesce(result->>'processed', '0') = '0'
          and coalesce(result->>'status', '') = 'done';
    -- Si falló pero reintentará, seguimos al siguiente job / siguiente minuto
    exit when coalesce(result->>'ok', 'true') = 'false';
  end loop;

  return jsonb_build_object('ok', true, 'processedTotal', total);
end;
$$;

revoke all on function public.process_notification_dispatch(int) from public;
revoke all on function public.process_notification_dispatch_tick(int, int) from public;
grant execute on function public.process_notification_dispatch(int) to service_role;
grant execute on function public.process_notification_dispatch_tick(int, int) to service_role;

-- =============================================================================
-- 2) Cron AUTOMÁTICO (se programa una vez; luego no tocas nada)
-- =============================================================================
create extension if not exists pg_cron with schema extensions;

-- Quita job anterior si existía (idempotente)
do $$
begin
  perform cron.unschedule('cofradeo-notification-dispatch');
exception
  when others then null;
end $$;

select cron.schedule(
  'cofradeo-notification-dispatch',
  '* * * * *',
  $$select public.process_notification_dispatch_tick(500, 8)$$
);

comment on function public.process_notification_dispatch_tick(int, int) is
  'Lo llama el Cron cada minuto. Tú no tienes que ejecutarlo a mano.';

notify pgrst, 'reload schema';
