-- Cofradero · permite a moderadores editar/borrar sus propios eventos
-- Ejecutar si un moderador puede crear pero no editar (p. ej. tras re-ejecutar calendar_events.sql).

create or replace function public.can_manage_calendar_event(
  p_user_id uuid,
  p_event_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.calendar_events e
    join public.profiles p on p.id = p_user_id
    where e.id = p_event_id
      and p.suspended_at is null
      and (
        public.is_admin_user(p_user_id)
        or (
          e.created_by = p_user_id
          and e.status in ('published', 'pending_review', 'rejected')
        )
      )
  );
$$;
