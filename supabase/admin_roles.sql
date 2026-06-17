-- Cofradero · roles de staff (Fase A)
-- Ejecutar en SQL Editor después de schema.sql

alter table public.profiles
  add column if not exists role text not null default 'member'
  check (role in ('member', 'editor', 'moderator', 'admin'));

-- Asignar tu cuenta admin (ajusta el handle):
-- update public.profiles set role = 'admin' where handle = 'jcaro';

create or replace function public.is_staff_user(p_user_id uuid)
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
      and role in ('admin', 'moderator')
  );
$$;

-- Solo bloquea que el usuario cambie SU PROPIO rol desde la app.
-- SQL Editor / Table Editor (auth.uid() null) y service role pueden asignar roles.
create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and auth.uid() = old.id then
    raise exception 'No puedes cambiar tu propio rol desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_role_guard on public.profiles;
create trigger on_profile_role_guard
  before update on public.profiles
  for each row execute function public.prevent_profile_role_change();

-- Temas: staff ve pendientes ajenos + puede moderar
drop policy if exists "Temas publicados o propios" on public.forum_topics;

create policy "Temas visibles según rol"
  on public.forum_topics for select
  using (
    status = 'published'
    or author_id = auth.uid()
    or public.is_staff_user(auth.uid())
  );

create policy "Staff modera temas"
  on public.forum_topics for update
  using (public.is_staff_user(auth.uid()))
  with check (public.is_staff_user(auth.uid()));

-- Reportes: staff lee y resuelve
create policy "Staff lee reportes"
  on public.reports for select
  using (public.is_staff_user(auth.uid()));

create policy "Staff actualiza reportes"
  on public.reports for update
  using (public.is_staff_user(auth.uid()))
  with check (public.is_staff_user(auth.uid()));
