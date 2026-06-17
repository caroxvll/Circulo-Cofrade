-- Cofradero · bucket avatares (Fase 8c)
-- Ejecutar en SQL Editor después de schema.sql

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatares públicos" on storage.objects;
create policy "Avatares públicos"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "Usuario sube su avatar" on storage.objects;
create policy "Usuario sube su avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Usuario actualiza su avatar" on storage.objects;
create policy "Usuario actualiza su avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Usuario borra su avatar" on storage.objects;
create policy "Usuario borra su avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Contador de seguidores al seguir/dejar de seguir un perfil
create or replace function public.handle_profile_follow_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.target_type = 'profile' then
    update public.profiles
    set follower_count = follower_count + 1
    where id::text = new.target_id;
  elsif tg_op = 'DELETE' and old.target_type = 'profile' then
    update public.profiles
    set follower_count = greatest(follower_count - 1, 0)
    where id::text = old.target_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists on_profile_follow_count on public.follows;
create trigger on_profile_follow_count
  after insert or delete on public.follows
  for each row execute function public.handle_profile_follow_count();
