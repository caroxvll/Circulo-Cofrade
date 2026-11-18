-- Cofradeo · publicaciones oficiales de Círculo Cofrade (Para ti)
-- Idempotente. Ejecutar en SQL Editor (PRE/PROD).

alter table public.forum_topics
  add column if not exists is_editorial boolean not null default false;

alter table public.forum_topics
  add column if not exists via_author_id uuid
    references public.profiles (id) on delete set null;

create index if not exists forum_topics_editorial_published_idx
  on public.forum_topics (created_at desc)
  where is_editorial = true and status = 'published';

comment on column public.forum_topics.is_editorial is
  'Publicación oficial de Círculo Cofrade para Para ti (no aparece en el listado del foro; sí admite detalle y comentarios).';

comment on column public.forum_topics.via_author_id is
  'Quién redactó la publicación editorial; la marca pública es Círculo Cofrade.';

-- Junta crea editoriales. Admin → published; moderador → pending.
create or replace function public.create_editorial_post(
  p_title text,
  p_body text,
  p_excerpt text default null,
  p_cover_image_url text default null
)
returns public.forum_topics
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_handle text;
  v_status text;
  v_title text := trim(coalesce(p_title, ''));
  v_body text := trim(coalesce(p_body, ''));
  v_excerpt text;
  v_row public.forum_topics;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_junta_member(v_uid) then
    raise exception 'Solo la Junta puede crear publicaciones oficiales';
  end if;

  if char_length(v_title) < 3 then
    raise exception 'El título es demasiado corto';
  end if;

  if char_length(v_body) < 1 and coalesce(nullif(trim(p_cover_image_url), ''), '') = '' then
    raise exception 'Escribe un texto o añade una imagen';
  end if;

  select handle into v_handle
  from public.profiles
  where id = v_uid;

  if v_handle is null or trim(v_handle) = '' then
    v_handle := 'junta';
  end if;

  v_excerpt := nullif(trim(coalesce(p_excerpt, '')), '');
  if v_excerpt is null then
    v_excerpt := left(regexp_replace(v_body, E'\\s+', ' ', 'g'), 180);
  end if;
  if v_excerpt is null or v_excerpt = '' then
    v_excerpt := v_title;
  end if;

  if public.is_admin_user(v_uid) then
    v_status := 'published';
  else
    v_status := 'pending';
  end if;

  insert into public.forum_topics (
    id,
    forum_id,
    author_id,
    author_handle,
    title,
    excerpt,
    body,
    status,
    is_editorial,
    via_author_id,
    cover_image_url,
    is_system,
    is_pinned,
    is_listed
  ) values (
    'editorial-' || replace(gen_random_uuid()::text, '-', ''),
    'foro-cofradiero',
    v_uid,
    '@cofradeo',
    v_title,
    v_excerpt,
    coalesce(nullif(v_body, ''), v_title),
    v_status,
    true,
    v_uid,
    nullif(trim(coalesce(p_cover_image_url, '')), ''),
    false,
    false,
    false
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.create_editorial_post(text, text, text, text) from public;
grant execute on function public.create_editorial_post(text, text, text, text) to authenticated;

-- Ya publicadas: fuera del listado del foro (siguen en Para ti + detalle).
update public.forum_topics
set is_listed = false
where is_editorial = true
  and is_listed = true;

-- Portada: el creador (via/author) o staff puede fijarla en editoriales.
create or replace function public.set_editorial_cover(
  p_topic_id text,
  p_cover_image_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_topic public.forum_topics%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_topic
  from public.forum_topics
  where id = p_topic_id;

  if not found or v_topic.is_editorial is not true then
    raise exception 'not found';
  end if;

  if v_topic.via_author_id is distinct from v_uid
     and v_topic.author_id is distinct from v_uid
     and not public.is_junta_member(v_uid) then
    raise exception 'forbidden';
  end if;

  update public.forum_topics
  set cover_image_url = nullif(trim(coalesce(p_cover_image_url, '')), ''),
      edited_at = now()
  where id = p_topic_id;
end;
$$;

revoke all on function public.set_editorial_cover(text, text) from public;
grant execute on function public.set_editorial_cover(text, text) to authenticated;

notify pgrst, 'reload schema';
