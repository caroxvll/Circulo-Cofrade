-- Cofradeo · vídeo en publicaciones oficiales (Para ti)
-- Idempotente. Ejecutar en SQL Editor (PRE/PROD) tras editorial_posts.sql.
-- Fase 2a: MP4 en R2; FFmpeg/HLS llega después.

alter table public.forum_topics
  add column if not exists video_url text;

alter table public.forum_topics
  add column if not exists video_poster_url text;

alter table public.forum_topics
  add column if not exists video_status text;

alter table public.forum_topics
  drop constraint if exists forum_topics_video_status_check;

alter table public.forum_topics
  add constraint forum_topics_video_status_check
  check (
    video_status is null
    or video_status in ('uploading', 'processing', 'ready', 'failed')
  );

comment on column public.forum_topics.video_url is
  'URL pública del vídeo editorial (R2/CDN). Solo editoriales.';

comment on column public.forum_topics.video_poster_url is
  'Poster/frame del vídeo; si es null se usa cover_image_url.';

comment on column public.forum_topics.video_status is
  'uploading | processing | ready | failed. Null = sin vídeo.';

create index if not exists forum_topics_editorial_video_ready_idx
  on public.forum_topics (created_at desc)
  where is_editorial = true
    and status = 'published'
    and video_status = 'ready';

-- Junta marca el vídeo tras el PUT a R2 (o fallo).
create or replace function public.set_editorial_video(
  p_topic_id text,
  p_video_url text default null,
  p_video_poster_url text default null,
  p_video_status text default 'ready'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_topic public.forum_topics%rowtype;
  v_status text := nullif(trim(coalesce(p_video_status, '')), '');
  v_url text := nullif(trim(coalesce(p_video_url, '')), '');
  v_poster text := nullif(trim(coalesce(p_video_poster_url, '')), '');
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

  if v_status is null then
    v_status := 'ready';
  end if;

  if v_status not in ('uploading', 'processing', 'ready', 'failed') then
    raise exception 'invalid video_status';
  end if;

  if v_status = 'ready' and v_url is null then
    raise exception 'video_url required when ready';
  end if;

  update public.forum_topics
  set video_url = case
        when v_status in ('failed') and v_url is null then video_url
        else v_url
      end,
      video_poster_url = coalesce(v_poster, video_poster_url),
      video_status = v_status,
      cover_image_url = coalesce(v_poster, cover_image_url),
      edited_at = now()
  where id = p_topic_id;
end;
$$;

revoke all on function public.set_editorial_video(text, text, text, text) from public;
grant execute on function public.set_editorial_video(text, text, text, text) to authenticated;

notify pgrst, 'reload schema';
