-- Cofradero · portadas de foro + hero global de la pantalla FOROS
-- Ejecutar después de forum_pillar_icons.sql. Idempotente.

alter table public.forum_pillars
  add column if not exists cover_image_url text;

create table if not exists public.app_config (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "App config lectura publica" on public.app_config;
create policy "App config lectura publica"
  on public.app_config for select
  using (true);

drop policy if exists "Admin gestiona app config" on public.app_config;
create policy "Admin gestiona app config"
  on public.app_config for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

insert into public.app_config (key, value)
values ('forums_list_hero_image_url', '')
on conflict (key) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-covers',
  'forum-covers',
  true,
  5242880,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Portadas foro lectura publica" on storage.objects;
create policy "Portadas foro lectura publica"
  on storage.objects for select
  using (bucket_id = 'forum-covers');

drop policy if exists "Admin sube portadas foro" on storage.objects;
create policy "Admin sube portadas foro"
  on storage.objects for insert
  with check (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin actualiza portadas foro" on storage.objects;
create policy "Admin actualiza portadas foro"
  on storage.objects for update
  using (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  )
  with check (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin borra portadas foro" on storage.objects;
create policy "Admin borra portadas foro"
  on storage.objects for delete
  using (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  );
