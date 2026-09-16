-- Cofradero · cuentas verificadas
-- Ejecutar después de schema.sql y admin_roles.sql.

alter table public.profiles
  add column if not exists verified boolean not null default false;

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
      and suspended_at is null
  );
$$;

-- Evita que una cuenta se marque a sí misma como verificada desde la app.
-- SQL Editor / Table Editor (auth.uid() null) y service role pueden gestionarlo.
create or replace function public.prevent_profile_verified_self_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verified is distinct from old.verified
     and auth.uid() is not null
     and auth.uid() = old.id
     and not public.is_admin_user(auth.uid()) then
    raise exception 'No puedes cambiar tu propia verificación desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_verified_guard on public.profiles;
create trigger on_profile_verified_guard
  before update on public.profiles
  for each row execute function public.prevent_profile_verified_self_change();

drop policy if exists "Admin actualiza verificaciones de perfiles"
  on public.profiles;

create policy "Admin actualiza verificaciones de perfiles"
  on public.profiles for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Ejemplos:
-- update public.profiles set verified = true where handle = 'hermandad_sevilla';
-- update public.profiles set verified = false where handle = 'hermandad_sevilla';
