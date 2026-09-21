-- Cofradero · Hermandades verificadas pueden proponer/publicar en calendario
-- Ejecutar después de roles_v2.sql y hermandad_official_posts.sql

create or replace function public.is_verified_hermandad_publisher(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.hermandad_topic_accounts a on a.profile_id = p.id
    where p.id = p_user_id
      and p.account_type = 'brotherhood'
      and p.verified = true
      and p.suspended_at is null
  );
$$;

create or replace function public.can_submit_calendar_events(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_junta_member(p_user_id)
      or public.is_verified_hermandad_publisher(p_user_id);
$$;

create or replace function public.set_calendar_event_status_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin_user(new.created_by) then
    new.status := coalesce(nullif(new.status, ''), 'published');
  elsif public.is_verified_hermandad_publisher(new.created_by) then
    -- Oficial de hermandad: entra publicado (calendario operativo).
    new.status := coalesce(nullif(new.status, ''), 'published');
  elsif public.can_submit_calendar_events(new.created_by) then
    new.status := 'pending_review';
  else
    raise exception 'No tienes permiso para crear eventos en el calendario';
  end if;
  return new;
end;
$$;
