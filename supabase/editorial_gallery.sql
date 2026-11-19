-- Cofradeo · varias fotos en una publicación de Círculo Cofrade (Para ti)
-- Idempotente. Ejecutar en SQL Editor (PRE/PROD) después de editorial_posts.sql.

alter table public.forum_topics
  add column if not exists gallery_image_urls text[] not null default '{}';

comment on column public.forum_topics.gallery_image_urls is
  'Fotos detrás de la portada, en orden. La de delante sigue en cover_image_url. Máximo 3.';

-- Portada + montón. La portada no va repetida en el array.
create or replace function public.set_editorial_gallery(
  p_topic_id text,
  p_cover_image_url text,
  p_gallery_image_urls text[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_topic public.forum_topics%rowtype;
  v_gallery text[];
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

  select coalesce(array_agg(u order by ord), '{}')
  into v_gallery
  from (
    select nullif(trim(item), '') as u, ord
    from unnest(coalesce(p_gallery_image_urls, '{}')) with ordinality as t(item, ord)
  ) cleaned
  where u is not null;

  if coalesce(array_length(v_gallery, 1), 0) > 3 then
    raise exception 'Máximo 4 fotos';
  end if;

  update public.forum_topics
  set cover_image_url = nullif(trim(coalesce(p_cover_image_url, '')), ''),
      gallery_image_urls = v_gallery,
      edited_at = now()
  where id = p_topic_id;
end;
$$;

revoke all on function public.set_editorial_gallery(text, text, text[]) from public;
grant execute on function public.set_editorial_gallery(text, text, text[]) to authenticated;

notify pgrst, 'reload schema';
