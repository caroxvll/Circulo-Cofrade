-- Cofradero · imágenes en publicaciones oficiales de Hermandades
-- Ejecutar después de hermandad_official_posts.sql y hermandad_scheduled_posts.sql.

alter table public.forum_replies
  add column if not exists image_url text;

alter table public.hermandad_scheduled_posts
  add column if not exists image_url text;

create or replace function public.publish_due_hermandad_scheduled_posts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_reply_id uuid;
  v_count integer := 0;
begin
  for v_row in
    select *
    from public.hermandad_scheduled_posts
    where status = 'scheduled'
      and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    insert into public.forum_replies (
      topic_id,
      author_id,
      author_handle,
      content,
      is_official,
      official_category,
      image_url
    ) values (
      v_row.topic_id,
      v_row.author_id,
      v_row.author_handle,
      v_row.content,
      true,
      v_row.official_category,
      v_row.image_url
    )
    returning id into v_reply_id;

    update public.hermandad_scheduled_posts
    set status = 'published',
        published_reply_id = v_reply_id,
        updated_at = now()
    where id = v_row.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-post-images',
  'forum-post-images',
  true,
  5242880,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Imagenes publicacion lectura publica" on storage.objects;
create policy "Imagenes publicacion lectura publica"
  on storage.objects for select
  using (bucket_id = 'forum-post-images');

drop policy if exists "Oficial sube imagenes publicacion" on storage.objects;
create policy "Oficial sube imagenes publicacion"
  on storage.objects for insert
  with check (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  );

drop policy if exists "Oficial actualiza imagenes publicacion" on storage.objects;
create policy "Oficial actualiza imagenes publicacion"
  on storage.objects for update
  using (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  )
  with check (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  );

drop policy if exists "Oficial borra imagenes publicacion" on storage.objects;
create policy "Oficial borra imagenes publicacion"
  on storage.objects for delete
  using (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  );
