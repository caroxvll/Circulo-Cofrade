-- Cofradero · portadas de tema subidas por el titular del hilo
-- Ejecutar después de pinned_topics_admin.sql (bucket topic-covers).
-- Permite adjuntar un cartel/foto al crear (o editar) un tema propio.

alter table public.forum_topics
  add column if not exists cover_image_url text;

-- Titular (o staff) puede subir/actualizar/borrar portadas en topic-covers/{topic_id}/...
drop policy if exists "Titular o staff sube portadas temas" on storage.objects;
create policy "Titular o staff sube portadas temas"
  on storage.objects for insert
  with check (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  );

drop policy if exists "Titular o staff actualiza portadas temas" on storage.objects;
create policy "Titular o staff actualiza portadas temas"
  on storage.objects for update
  using (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  )
  with check (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  );

drop policy if exists "Titular o staff borra portadas temas" on storage.objects;
create policy "Titular o staff borra portadas temas"
  on storage.objects for delete
  using (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  );

-- Las políticas antiguas solo-staff quedan sustituidas por las de arriba.
drop policy if exists "Staff sube portadas temas" on storage.objects;
drop policy if exists "Staff actualiza portadas temas" on storage.objects;
drop policy if exists "Staff borra portadas temas" on storage.objects;
