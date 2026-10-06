-- Cofradeo · cola de ENTREGA push (FCM)
-- Separado de notification_dispatch_jobs (esa crea filas en notifications;
-- esta controla cuándo se llama a Google FCM).
--
-- Orden: ejecutar en SQL Editor una vez.
-- Después: npx supabase functions deploy drain-push
-- IMPORTANTE: desactiva el Database Webhook "notifications-push" si existe
-- (si no, seguirías disparando send-push en paralelo y duplicarías pushes).

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

-- =============================================================================
-- 1) Cola
-- =============================================================================
create table if not exists public.push_delivery_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  subtitle text,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'done', 'failed', 'skipped')),
  retry_count int not null default 0,
  last_error text,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (notification_id)
);

create index if not exists push_delivery_jobs_pending_idx
  on public.push_delivery_jobs (created_at)
  where status = 'pending';

create index if not exists push_delivery_jobs_processing_idx
  on public.push_delivery_jobs (claimed_at)
  where status = 'processing';

create index if not exists push_delivery_jobs_user_idx
  on public.push_delivery_jobs (user_id, created_at desc);

alter table public.push_delivery_jobs enable row level security;

-- Solo service_role / security definer; sin policies para authenticated.
drop policy if exists "Staff no lee push_delivery_jobs" on public.push_delivery_jobs;

comment on table public.push_delivery_jobs is
  'Cola de envío FCM. Encolar al insertar notifications; drain-push drena con paralelismo controlado.';

-- Anti-ráfaga de kicks HTTP (un “toque” al worker cada pocos segundos).
create table if not exists public.push_delivery_kick_state (
  id int primary key default 1 check (id = 1),
  last_kick_at timestamptz not null default '1970-01-01'::timestamptz
);

insert into public.push_delivery_kick_state (id, last_kick_at)
values (1, '1970-01-01'::timestamptz)
on conflict (id) do nothing;

alter table public.push_delivery_kick_state enable row level security;
-- Sin policies: anon/authenticated no leen ni escriben; solo security definer / service_role.

revoke all on table public.push_delivery_kick_state from anon, authenticated;
revoke all on table public.push_delivery_jobs from anon, authenticated;
-- Lectura admin vía RLS (policy más abajo / push_delivery_admin.sql).
grant select on public.push_delivery_jobs to authenticated;

-- =============================================================================
-- 2) Encolar al crear notificaciones (por LOTE, no fila a fila)
-- =============================================================================
create or replace function public.enqueue_push_delivery_from_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_delivery_jobs (
    notification_id,
    user_id,
    type,
    title,
    subtitle,
    payload
  )
  select
    n.id,
    n.user_id,
    n.type,
    n.title,
    n.subtitle,
    coalesce(n.payload, '{}'::jsonb)
  from new_rows n
  on conflict (notification_id) do nothing;

  perform public.kick_push_delivery_drain();
  return null;
end;
$$;

-- Quita el disparo directo a send-push (1 HTTP por fila).
drop trigger if exists notifications_send_push on public.notifications;
drop trigger if exists notifications_enqueue_push on public.notifications;

create trigger notifications_enqueue_push
  after insert on public.notifications
  referencing new table as new_rows
  for each statement
  execute function public.enqueue_push_delivery_from_notifications();

-- =============================================================================
-- 3) Kick al worker (rate-limited) + Cron de seguridad
-- =============================================================================
create or replace function public.kick_push_delivery_drain()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  should_kick boolean := false;
  fn_url text;
  service_key text;
begin
  -- Como máximo 1 kick cada 3 s (aunque entren 500 inserts en un lote).
  update public.push_delivery_kick_state
  set last_kick_at = now()
  where id = 1
    and last_kick_at < now() - interval '3 seconds'
  returning true into should_kick;

  if not coalesce(should_kick, false) then
    return;
  end if;

  fn_url := current_setting('app.settings.drain_push_url', true);
  if fn_url is null or length(trim(fn_url)) = 0 then
    fn_url := 'https://dcsxgppprfedrsrtbatx.supabase.co/functions/v1/drain-push';
  end if;

  service_key := current_setting('app.settings.service_role_key', true);

  perform net.http_post(
    url := fn_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce('Bearer ' || nullif(service_key, ''), '')
    ),
    body := jsonb_build_object(
      'batchSize', 40,
      'maxBatches', 25,
      'concurrency', 20
    )
  );
end;
$$;

-- Cron: por si el kick falló o quedó cola residual.
do $$
begin
  perform cron.unschedule('cofradeo-push-delivery-drain');
exception
  when others then null;
end $$;

select cron.schedule(
  'cofradeo-push-delivery-drain',
  '* * * * *',
  $$select public.kick_push_delivery_drain()$$
);

-- =============================================================================
-- 4) RPCs para la Edge Function (claim / finish / borrar token)
-- =============================================================================
create or replace function public.claim_push_delivery_jobs(p_limit int default 40)
returns setof public.push_delivery_jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  batch_limit int := least(greatest(coalesce(p_limit, 40), 1), 100);
begin
  -- Recupera jobs atascados en processing (> 2 min).
  update public.push_delivery_jobs
  set
    status = 'pending',
    updated_at = now(),
    last_error = coalesce(last_error, 'reclaimed stale processing')
  where status = 'processing'
    and claimed_at < now() - interval '2 minutes';

  return query
  with picked as (
    select j.id
    from public.push_delivery_jobs j
    where j.status = 'pending'
      and j.retry_count < 5
    order by j.created_at
    for update skip locked
    limit batch_limit
  )
  update public.push_delivery_jobs j
  set
    status = 'processing',
    claimed_at = now(),
    updated_at = now()
  from picked
  where j.id = picked.id
  returning j.*;
end;
$$;

create or replace function public.finish_push_delivery_job(
  p_id uuid,
  p_status text,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  st text := lower(coalesce(p_status, 'failed'));
begin
  if st not in ('done', 'failed', 'skipped', 'pending') then
    raise exception 'status inválido: %', p_status;
  end if;

  update public.push_delivery_jobs
  set
    status = case
      when st = 'pending' then 'pending'
      when st = 'skipped' then 'skipped'
      when st = 'done' then 'done'
      when st = 'failed' and retry_count + 1 >= 5 then 'failed'
      when st = 'failed' then 'pending' -- reintento
      else st
    end,
    retry_count = case
      when st = 'failed' then retry_count + 1
      else retry_count
    end,
    last_error = case
      when p_error is null then last_error
      else left(p_error, 500)
    end,
    claimed_at = case when st in ('done', 'skipped') then claimed_at else null end,
    updated_at = now()
  where id = p_id;
end;
$$;

create or replace function public.delete_device_token_by_fcm(p_fcm_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_fcm_token is null or length(trim(p_fcm_token)) = 0 then
    return;
  end if;
  delete from public.device_tokens where fcm_token = p_fcm_token;
end;
$$;

create or replace function public.staff_push_delivery_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  select jsonb_build_object(
    'pending', count(*) filter (where status = 'pending'),
    'processing', count(*) filter (where status = 'processing'),
    'done', count(*) filter (where status = 'done'),
    'failed', count(*) filter (where status = 'failed'),
    'skipped', count(*) filter (where status = 'skipped'),
    'doneLast24h', count(*) filter (
      where status = 'done' and updated_at > now() - interval '24 hours'
    ),
    'failedLast24h', count(*) filter (
      where status = 'failed' and updated_at > now() - interval '24 hours'
    ),
    'oldestPendingAt', min(created_at) filter (where status = 'pending')
  )
  into result
  from public.push_delivery_jobs;

  return coalesce(result, '{}'::jsonb);
end;
$$;

create or replace function public.staff_retry_failed_push_jobs()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  update public.push_delivery_jobs
  set
    status = 'pending',
    retry_count = 0,
    last_error = null,
    claimed_at = null,
    updated_at = now()
  where status = 'failed';

  get diagnostics n = row_count;
  perform public.kick_push_delivery_drain();
  return n;
end;
$$;

create or replace function public.staff_kick_push_delivery()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  -- Fuerza un kick aunque el rate-limit diga que aún no toca.
  update public.push_delivery_kick_state
  set last_kick_at = '1970-01-01'::timestamptz
  where id = 1;

  perform public.kick_push_delivery_drain();
  return jsonb_build_object('ok', true, 'kicked', true);
end;
$$;

drop policy if exists "Admin lee cola push FCM" on public.push_delivery_jobs;
create policy "Admin lee cola push FCM"
  on public.push_delivery_jobs
  for select
  using (public.is_admin_user(auth.uid()));

revoke all on function public.claim_push_delivery_jobs(int) from public;
revoke all on function public.finish_push_delivery_job(uuid, text, text) from public;
revoke all on function public.delete_device_token_by_fcm(text) from public;
revoke all on function public.kick_push_delivery_drain() from public;
revoke all on function public.staff_push_delivery_overview() from public;
revoke all on function public.staff_retry_failed_push_jobs() from public;
revoke all on function public.staff_kick_push_delivery() from public;

grant execute on function public.claim_push_delivery_jobs(int) to service_role;
grant execute on function public.finish_push_delivery_job(uuid, text, text) to service_role;
grant execute on function public.delete_device_token_by_fcm(text) to service_role;
grant execute on function public.kick_push_delivery_drain() to service_role;
grant execute on function public.staff_push_delivery_overview() to authenticated;
grant execute on function public.staff_retry_failed_push_jobs() to authenticated;
grant execute on function public.staff_kick_push_delivery() to authenticated;

comment on function public.kick_push_delivery_drain() is
  'Llama a drain-push (máx. 1 vez / 3 s). Cron cada minuto como red de seguridad.';

notify pgrst, 'reload schema';
