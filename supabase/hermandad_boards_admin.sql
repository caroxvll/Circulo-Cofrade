-- Cofradero · Admin puede crear/gestionar tablones del directorio Hermandades
-- Ejecutar en Supabase → SQL Editor después de hermandad_official_posts.sql

-- 1) El guard ya no bloquea a admin (sigue bloqueando app / usuarios normales).
create or replace function public.prevent_manual_hermandad_topics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id = 'hermandades'
     and auth.uid() is not null
     and not exists (
       select 1
       from public.profiles p
       where p.id = auth.uid()
         and p.role = 'admin'
         and p.suspended_at is null
     ) then
    raise exception
      'Hermandades es un directorio informativo: no admite temas nuevos desde la app';
  end if;
  return new;
end;
$$;

-- 2) Política de inserción de tablones (admin).
drop policy if exists "Admin crea tablones hermandad" on public.forum_topics;
create policy "Admin crea tablones hermandad"
  on public.forum_topics for insert
  with check (
    forum_id = 'hermandades'
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
        and p.suspended_at is null
    )
  );
