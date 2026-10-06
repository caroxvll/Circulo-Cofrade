-- Cofradero · fin editable + cierre forzado del live por evento
-- (ensayo, iguala, procesión, concierto…). Ejecutar en SQL Editor.

alter table public.calendar_events
  add column if not exists ends_at timestamptz;

alter table public.calendar_events
  add column if not exists live_force_state text not null default 'auto';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'calendar_events_live_force_state_check'
  ) then
    alter table public.calendar_events
      add constraint calendar_events_live_force_state_check
      check (live_force_state in ('auto', 'open', 'closed'));
  end if;
end $$;

comment on column public.calendar_events.ends_at is
  'Fin estimado del evento/live. Null = duración por defecto en la app.';
comment on column public.calendar_events.live_force_state is
  'auto = ventana starts/ends; open = forzar live; closed = finalizado a mano (p. ej. lluvia).';

-- Publicar avisos de ensayo/procesión/etc. alineado con UI.
create or replace function public.can_post_event_live_update(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.calendar_events e
    where e.id = p_event_id
      and e.status = 'published'
      and e.event_type in ('ensayo', 'iguala', 'procesion', 'concierto', 'gloria', 'evento')
      and (
        e.live_force_state = 'open'
        or (
          e.live_force_state = 'auto'
          and e.starts_at <= now()
          and coalesce(
            e.ends_at,
            e.starts_at + case e.event_type
              when 'procesion' then interval '4 hours'
              when 'ensayo' then interval '4 hours'
              when 'iguala' then interval '4 hours'
              when 'gloria' then interval '2 hours'
              when 'concierto' then interval '2 hours'
              else interval '2 hours'
            end
          ) > now()
        )
      )
  );
$$;

grant execute on function public.can_post_event_live_update(uuid) to authenticated;

-- Staff / junta: forzar cierre o reapertura del live.
create or replace function public.admin_set_event_live_force_state(
  p_event_id uuid,
  p_force_state text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_force_state is null
     or p_force_state not in ('auto', 'open', 'closed') then
    raise exception 'invalid force state';
  end if;

  if auth.uid() is null
     or not (
       public.is_admin_user(auth.uid())
       or public.is_junta_member(auth.uid())
     ) then
    raise exception 'not authorized';
  end if;

  update public.calendar_events
  set
    live_force_state = p_force_state,
    updated_at = now()
  where id = p_event_id;

  if not found then
    raise exception 'event not found';
  end if;
end;
$$;

grant execute on function public.admin_set_event_live_force_state(uuid, text)
  to authenticated;

comment on function public.admin_set_event_live_force_state(uuid, text) is
  'Admin/Junta: auto | open | closed sobre el live de un evento de calendario.';
