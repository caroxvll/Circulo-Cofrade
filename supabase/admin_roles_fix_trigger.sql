-- Cofradero · corrección trigger roles
-- Ejecutar si no te deja cambiar role en Table Editor / SQL Editor

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

-- Asignar admin (ajusta el handle):
-- update public.profiles set role = 'admin' where handle = 'jcaro';
