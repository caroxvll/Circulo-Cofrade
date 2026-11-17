-- Cofradeo · limpiar historial de colas (dispatch + FCM)
-- Solo borra trabajos terminados (done / failed / skipped). No toca pendientes.
-- Ejecutar en SQL Editor (idempotente).

create or replace function public.staff_purge_notification_queues(
  p_days int default 7
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days int := greatest(1, least(coalesce(p_days, 7), 365));
  v_cutoff timestamptz := now() - make_interval(days => v_days);
  v_dispatch int := 0;
  v_push int := 0;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  delete from public.notification_dispatch_jobs
  where status in ('done', 'failed')
    and updated_at < v_cutoff;
  get diagnostics v_dispatch = row_count;

  delete from public.push_delivery_jobs
  where status in ('done', 'failed', 'skipped')
    and updated_at < v_cutoff;
  get diagnostics v_push = row_count;

  return jsonb_build_object(
    'ok', true,
    'days', v_days,
    'dispatchDeleted', v_dispatch,
    'pushDeleted', v_push
  );
end;
$$;

revoke all on function public.staff_purge_notification_queues(int) from public;
grant execute on function public.staff_purge_notification_queues(int) to authenticated;

comment on function public.staff_purge_notification_queues(int) is
  'Admin: borra historial de colas (done/failed/skipped) más antiguo que N días.';

notify pgrst, 'reload schema';
