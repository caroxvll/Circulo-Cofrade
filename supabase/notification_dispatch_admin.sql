-- Cofradero · Panel admin: ver / empujar la cola de notificaciones
-- Ejecutar tras notification_dispatch_cron.sql (o al menos v1+v2).
-- Idempotente.

-- Lectura para admins (web admin-web)
drop policy if exists "Admin lee cola de envío" on public.notification_dispatch_jobs;
create policy "Admin lee cola de envío"
  on public.notification_dispatch_jobs
  for select
  using (public.is_admin_user(auth.uid()));

-- Resumen para el panel
create or replace function public.staff_notification_dispatch_overview()
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
    'byStatus', coalesce((
      select jsonb_object_agg(status, cnt)
      from (
        select status, count(*)::int as cnt
        from public.notification_dispatch_jobs
        group by status
      ) s
    ), '{}'::jsonb),
    'byKindPending', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'kind', kind,
          'jobs', jobs,
          'processed', processed
        )
        order by jobs desc
      )
      from (
        select
          kind,
          count(*)::int as jobs,
          coalesce(sum(processed_count), 0)::int as processed
        from public.notification_dispatch_jobs
        where status in ('pending', 'processing', 'failed')
        group by kind
      ) k
    ), '[]'::jsonb),
    'pendingCount', (
      select count(*)::int
      from public.notification_dispatch_jobs
      where status in ('pending', 'processing')
    ),
    'failedCount', (
      select count(*)::int
      from public.notification_dispatch_jobs
      where status = 'failed'
    ),
    'doneLast24h', (
      select count(*)::int
      from public.notification_dispatch_jobs
      where status = 'done'
        and updated_at > now() - interval '24 hours'
    ),
    'processedLast24h', (
      select coalesce(sum(processed_count), 0)::int
      from public.notification_dispatch_jobs
      where updated_at > now() - interval '24 hours'
    )
  )
  into result;

  return result;
end;
$$;

revoke all on function public.staff_notification_dispatch_overview() from public;
grant execute on function public.staff_notification_dispatch_overview() to authenticated;

-- Empujar un tick ya (sin esperar al minuto del Cron)
create or replace function public.staff_process_notification_dispatch(
  p_limit int default 500,
  p_max_jobs int default 8
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;
  return public.process_notification_dispatch_tick(p_limit, p_max_jobs);
end;
$$;

revoke all on function public.staff_process_notification_dispatch(int, int) from public;
grant execute on function public.staff_process_notification_dispatch(int, int) to authenticated;

-- Reabrir fallidos para que el Cron los reintente
create or replace function public.staff_retry_failed_notification_jobs()
returns integer
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

  update public.notification_dispatch_jobs
  set
    status = 'pending',
    retry_count = 0,
    error_message = null,
    updated_at = now()
  where status = 'failed';

  get diagnostics n = row_count;
  return n;
end;
$$;

revoke all on function public.staff_retry_failed_notification_jobs() from public;
grant execute on function public.staff_retry_failed_notification_jobs() to authenticated;

-- Botón admin-web: recargar caché de la API (equivalente a notify pgrst…)
create or replace function public.staff_reload_postgrest_schema()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;
  perform pg_notify('pgrst', 'reload schema');
  return jsonb_build_object('ok', true, 'message', 'Esquema de API recargado');
end;
$$;

revoke all on function public.staff_reload_postgrest_schema() from public;
grant execute on function public.staff_reload_postgrest_schema() to authenticated;

notify pgrst, 'reload schema';
