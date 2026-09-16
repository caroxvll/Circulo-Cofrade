-- Cofradero · editar y fijar comunicados oficiales publicados
-- Ejecutar después de hermandad_official_posts.sql y forum_official_post_images.sql.

create or replace function public.update_official_hermandad_post(
  p_reply_id uuid,
  p_content text,
  p_official_category text,
  p_image_url text default null,
  p_clear_image boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
  v_forum_id text;
  v_content text := trim(coalesce(p_content, ''));
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if coalesce(v_reply.is_official, false) = false then
    raise exception 'not_official';
  end if;

  if v_reply.deleted_at is not null then
    raise exception 'deleted';
  end if;

  select forum_id into v_forum_id
  from public.forum_topics
  where id = v_reply.topic_id;

  if v_forum_id is distinct from 'hermandades' then
    raise exception 'forbidden';
  end if;

  if not public.can_create_official_hermandad_post(auth.uid(), v_reply.topic_id) then
    raise exception 'forbidden';
  end if;

  if p_official_category not in ('noticia', 'culto', 'acto', 'patrimonio') then
    raise exception 'invalid_category';
  end if;

  if char_length(v_content) > 8000 then
    raise exception 'invalid_content';
  end if;

  if char_length(v_content) < 1
     and p_clear_image
     and (v_reply.image_url is null or trim(v_reply.image_url) = '') then
    raise exception 'invalid_content';
  end if;

  update public.forum_replies
  set content = v_content,
      official_category = p_official_category,
      image_url = case
        when p_clear_image then null
        when p_image_url is not null then nullif(trim(p_image_url), '')
        else image_url
      end,
      edited_at = now()
  where id = p_reply_id;
end;
$$;

create or replace function public.set_official_hermandad_post_pinned(
  p_reply_id uuid,
  p_pinned boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
  v_forum_id text;
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if coalesce(v_reply.is_official, false) = false or v_reply.deleted_at is not null then
    raise exception 'forbidden';
  end if;

  select forum_id into v_forum_id
  from public.forum_topics
  where id = v_reply.topic_id;

  if v_forum_id is distinct from 'hermandades' then
    raise exception 'forbidden';
  end if;

  if not public.can_create_official_hermandad_post(auth.uid(), v_reply.topic_id) then
    raise exception 'forbidden';
  end if;

  if coalesce(p_pinned, false) then
    update public.forum_replies
    set is_featured = false
    where topic_id = v_reply.topic_id
      and coalesce(is_official, false) = true
      and id is distinct from p_reply_id;
  end if;

  update public.forum_replies
  set is_featured = coalesce(p_pinned, false)
  where id = p_reply_id;
end;
$$;

grant execute on function public.update_official_hermandad_post(uuid, text, text, text, boolean)
  to authenticated;
grant execute on function public.set_official_hermandad_post_pinned(uuid, boolean)
  to authenticated;
