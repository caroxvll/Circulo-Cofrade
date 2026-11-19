-- Cofradeo · un aviso del directo de Cuaresma solo sale en Para ti si el admin
-- o un moderador de la Junta lo elige.
-- Idempotente. Ejecutar en SQL Editor después de event_live_updates.sql.

alter table public.event_live_updates
  add column if not exists featured_at timestamptz;

comment on column public.event_live_updates.featured_at is
  'Si no es null, el aviso se muestra en Para ti. Lo marca el admin o la Junta.';

create index if not exists event_live_updates_featured_idx
  on public.event_live_updates (featured_at desc)
  where featured_at is not null;

create or replace function public.set_event_live_para_ti(
  p_id uuid,
  p_show boolean
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_at timestamptz;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_admin_user(v_uid)
     and not public.is_junta_member(v_uid) then
    raise exception 'forbidden';
  end if;

  v_at := case when p_show then now() else null end;

  update public.event_live_updates
  set featured_at = v_at
  where id = p_id;

  if not found then
    raise exception 'not found';
  end if;

  return v_at;
end;
$$;

revoke all on function public.set_event_live_para_ti(uuid, boolean) from public;
grant execute on function public.set_event_live_para_ti(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
