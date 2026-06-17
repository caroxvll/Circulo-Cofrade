-- Cofradero · gestión de pilares de foro (solo admin)
-- Ejecutar en SQL Editor después de admin_roles.sql

create or replace function public.is_admin_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = p_user_id
      and role = 'admin'
  );
$$;

drop policy if exists "Admin actualiza pilares" on public.forum_pillars;
create policy "Admin actualiza pilares"
  on public.forum_pillars for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));
