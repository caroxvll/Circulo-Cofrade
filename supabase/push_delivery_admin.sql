-- Cofradeo · Admin: cola de entrega FCM (complemento de push_delivery_queue.sql)
-- Si ya ejecutaste push_delivery_queue.sql completo (con staff_*), este script
-- es idempotente: puedes volver a pegarlo sin problema.

drop policy if exists "Admin lee cola push FCM" on public.push_delivery_jobs;
create policy "Admin lee cola push FCM"
  on public.push_delivery_jobs
  for select
  using (public.is_admin_user(auth.uid()));

-- Hace falta GRANT; si no, RLS no llega a evaluarse (permission denied).
grant select on public.push_delivery_jobs to authenticated;

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

  update public.push_delivery_kick_state
  set last_kick_at = '1970-01-01'::timestamptz
  where id = 1;

  perform public.kick_push_delivery_drain();
  return jsonb_build_object('ok', true, 'kicked', true);
end;
$$;

revoke all on function public.staff_push_delivery_overview() from public;
revoke all on function public.staff_retry_failed_push_jobs() from public;
revoke all on function public.staff_kick_push_delivery() from public;

grant execute on function public.staff_push_delivery_overview() to authenticated;
grant execute on function public.staff_retry_failed_push_jobs() to authenticated;
grant execute on function public.staff_kick_push_delivery() to authenticated;

notify pgrst, 'reload schema';
