-- Cofradeo · una noticia de Círculo Cofrade puede quedar ligada a un evento de Cuaresma.
-- Idempotente. Ejecutar en SQL Editor después de editorial_posts.sql.
-- La noticia se queda en Para ti. El parte de texto del directo sigue siendo solo de ese día.

alter table public.forum_topics
  add column if not exists calendar_event_id uuid
    references public.calendar_events (id) on delete set null;

comment on column public.forum_topics.calendar_event_id is
  'Evento de Cuaresma del que sale esta noticia. Null si es una publicación suelta.';

create index if not exists forum_topics_editorial_event_idx
  on public.forum_topics (calendar_event_id, created_at desc)
  where is_editorial = true and calendar_event_id is not null;

drop function if exists public.create_editorial_post(text, text, text, text);

create or replace function public.create_editorial_post(
  p_title text,
  p_body text,
  p_excerpt text default null,
  p_cover_image_url text default null,
  p_calendar_event_id uuid default null
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

  if p_calendar_event_id is not null
     and not exists (
       select 1
       from public.calendar_events e
       where e.id = p_calendar_event_id
         and e.status = 'published'
     ) then
    raise exception 'event not found';
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
    calendar_event_id,
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
    p_calendar_event_id,
    false,
    false,
    false
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.create_editorial_post(text, text, text, text, uuid) from public;
grant execute on function public.create_editorial_post(text, text, text, text, uuid) to authenticated;

notify pgrst, 'reload schema';
