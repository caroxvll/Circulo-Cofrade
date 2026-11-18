-- Cofradeo · Fase 2b: HLS via Cloudflare Stream (+ fallback R2)
-- Idempotente. Ejecutar tras editorial_video.sql.

alter table public.forum_topics
  add column if not exists video_provider text;

alter table public.forum_topics
  add column if not exists video_external_id text;

alter table public.forum_topics
  drop constraint if exists forum_topics_video_provider_check;

alter table public.forum_topics
  add constraint forum_topics_video_provider_check
  check (
    video_provider is null
    or video_provider in ('r2', 'stream')
  );

comment on column public.forum_topics.video_url is
  'URL de reproducción: HLS (Stream) o MP4 (R2).';

comment on column public.forum_topics.video_provider is
  'r2 = MP4 directo; stream = Cloudflare Stream (HLS + poster).';

comment on column public.forum_topics.video_external_id is
  'UID de Cloudflare Stream (o key R2).';

create index if not exists forum_topics_editorial_video_processing_idx
  on public.forum_topics (created_at desc)
  where is_editorial = true
    and video_status = 'processing';

-- Sustituye la firma de 4 args (Fase 2a) por la de 6.
drop function if exists public.set_editorial_video(text, text, text, text);

create or replace function public.set_editorial_video(
  p_topic_id text,
  p_video_url text default null,
  p_video_poster_url text default null,
  p_video_status text default 'ready',
  p_video_provider text default null,
  p_video_external_id text default null
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
  v_provider text := nullif(trim(coalesce(p_video_provider, '')), '');
  v_external text := nullif(trim(coalesce(p_video_external_id, '')), '');
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

  if v_provider is not null and v_provider not in ('r2', 'stream') then
    raise exception 'invalid video_provider';
  end if;

  if v_status = 'ready' and v_url is null then
    raise exception 'video_url required when ready';
  end if;

  update public.forum_topics
  set video_url = case
        when v_status in ('failed') and v_url is null then video_url
        else coalesce(v_url, video_url)
      end,
      video_poster_url = coalesce(v_poster, video_poster_url),
      video_status = v_status,
      video_provider = coalesce(v_provider, video_provider),
      video_external_id = coalesce(v_external, video_external_id),
      cover_image_url = coalesce(v_poster, cover_image_url),
      edited_at = now()
  where id = p_topic_id;
end;
$$;

-- Solo la firma de 6 args (la de 4 ya se eliminó arriba con DROP).
revoke all on function public.set_editorial_video(text, text, text, text, text, text) from public;
grant execute on function public.set_editorial_video(text, text, text, text, text, text) to authenticated;

-- Service role / webhook: marcar ready sin auth de usuario (solo service_role).
create or replace function public.finalize_editorial_video(
  p_topic_id text,
  p_video_url text,
  p_video_poster_url text default null,
  p_video_external_id text default null,
  p_video_provider text default 'stream'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := nullif(trim(coalesce(p_video_url, '')), '');
  v_poster text := nullif(trim(coalesce(p_video_poster_url, '')), '');
  v_external text := nullif(trim(coalesce(p_video_external_id, '')), '');
  v_provider text := nullif(trim(coalesce(p_video_provider, '')), '');
begin
  if v_url is null then
    raise exception 'video_url required';
  end if;

  if v_provider is null then
    v_provider := 'stream';
  end if;

  update public.forum_topics
  set video_url = v_url,
      video_poster_url = coalesce(v_poster, video_poster_url),
      cover_image_url = coalesce(v_poster, cover_image_url),
      video_status = 'ready',
      video_provider = v_provider,
      video_external_id = coalesce(v_external, video_external_id),
      edited_at = now()
  where id = p_topic_id
    and is_editorial = true;

  if not found then
    raise exception 'not found';
  end if;
end;
$$;

revoke all on function public.finalize_editorial_video(text, text, text, text, text) from public;
grant execute on function public.finalize_editorial_video(text, text, text, text, text) to service_role;

notify pgrst, 'reload schema';
