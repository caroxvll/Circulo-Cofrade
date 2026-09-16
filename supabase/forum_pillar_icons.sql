-- Cofradero · iconos de foro (imagen + gestión admin)
-- Ejecutar después de admin_forum_pillars.sql. Idempotente.

alter table public.forum_pillars
  add column if not exists icon_image_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-icons',
  'forum-icons',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Iconos foro lectura publica" on storage.objects;
create policy "Iconos foro lectura publica"
  on storage.objects for select
  using (bucket_id = 'forum-icons');

drop policy if exists "Admin sube iconos foro" on storage.objects;
create policy "Admin sube iconos foro"
  on storage.objects for insert
  with check (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin actualiza iconos foro" on storage.objects;
create policy "Admin actualiza iconos foro"
  on storage.objects for update
  using (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  )
  with check (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin borra iconos foro" on storage.objects;
create policy "Admin borra iconos foro"
  on storage.objects for delete
  using (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin crea pilares" on public.forum_pillars;
create policy "Admin crea pilares"
  on public.forum_pillars for insert
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Admin borra pilares" on public.forum_pillars;
create policy "Admin borra pilares"
  on public.forum_pillars for delete
  using (public.is_admin_user(auth.uid()));
