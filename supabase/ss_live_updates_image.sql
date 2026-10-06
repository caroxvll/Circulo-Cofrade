-- Cofradeo · imagen opcional en avisos SS (reporteros / hermandades)
-- Ejecutar después de ss_live_updates.sql y ss_live_reporters.sql.
-- Idempotente.

alter table public.ss_live_updates
  add column if not exists image_url text
    check (
      image_url is null
      or char_length(trim(image_url)) between 8 and 800
    );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ss-live-images',
  'ss-live-images',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avisos SS imagen lectura publica" on storage.objects;
create policy "Avisos SS imagen lectura publica"
  on storage.objects for select
  using (bucket_id = 'ss-live-images');

drop policy if exists "Reporteros suben imagen aviso SS" on storage.objects;
create policy "Reporteros suben imagen aviso SS"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'ss-live-images'
    and public.can_post_ss_live_update(auth.uid())
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Reporteros actualizan imagen aviso SS" on storage.objects;
create policy "Reporteros actualizan imagen aviso SS"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'ss-live-images'
    and public.can_post_ss_live_update(auth.uid())
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'ss-live-images'
    and public.can_post_ss_live_update(auth.uid())
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Reporteros borran imagen aviso SS" on storage.objects;
create policy "Reporteros borran imagen aviso SS"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'ss-live-images'
    and public.can_post_ss_live_update(auth.uid())
    and (storage.foldername(name))[1] = auth.uid()::text
  );

notify pgrst, 'reload schema';
