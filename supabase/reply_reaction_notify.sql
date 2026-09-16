-- Cofradero · aviso al autor + listado de reacciones
-- Ejecutar tras reply_reactions_emoji.sql (o reply_reactions_fix.sql)

alter table public.notification_preferences
  add column if not exists notify_reactions boolean not null default true;

create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    else true
  end;
$$;

create or replace function public.notify_on_reply_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply record;
  v_topic record;
  v_reactor record;
  v_existing record;
  v_latest_handle text;
  v_first_handle text;
  v_count int;
  v_subtitle text;
  v_payload jsonb;
begin
  perform set_config('row_security', 'off', true);

  select id, topic_id, author_id, official_category
  into v_reply
  from public.forum_replies
  where id = new.reply_id;

  if not found or v_reply.author_id is null then
    return new;
  end if;

  if v_reply.author_id = new.user_id then
    return new;
  end if;

  if not public.is_not_blocked(v_reply.author_id, new.user_id) then
    return new;
  end if;

  if not public.notify_pref_enabled(v_reply.author_id, 'reactions') then
    return new;
  end if;

  select id, forum_id, title
  into v_topic
  from public.forum_topics
  where id = v_reply.topic_id;

  if not found then
    return new;
  end if;

  select handle, display_name
  into v_reactor
  from public.profiles
  where id = new.user_id;

  v_latest_handle := coalesce(v_reactor.handle, '@cofrade');

  v_payload := jsonb_build_object(
    'forumId', v_topic.forum_id,
    'topicId', v_topic.id,
    'replyId', v_reply.id::text,
    'profileId', new.user_id::text,
    'firstProfileId', new.user_id::text,
    'reaction', new.reaction,
    'lastReaction', new.reaction,
    'officialCategory', v_reply.official_category,
    'reactorCount', 1,
    'firstHandle', v_latest_handle
  );

  select id, payload
  into v_existing
  from public.notifications
  where user_id = v_reply.author_id
    and type = 'reply_reaction'
    and read_at is null
    and payload->>'replyId' = v_reply.id::text
  order by created_at desc
  limit 1;

  if found then
    v_count := coalesce((v_existing.payload->>'reactorCount')::int, 1) + 1;
    v_first_handle := coalesce(
      v_existing.payload->>'firstHandle',
      v_existing.title
    );

    v_subtitle := case v_count
      when 2 then
        v_first_handle || ' y ' || v_latest_handle || ' reaccionaron a tu comentario'
      else
        v_count::text || ' personas reaccionaron a tu comentario'
    end;

    v_payload := v_existing.payload || jsonb_build_object(
      'reactorCount', v_count,
      'profileId', new.user_id::text,
      'reaction', new.reaction,
      'lastReaction', new.reaction
    );

    update public.notifications
    set
      title = v_latest_handle,
      subtitle = v_subtitle,
      payload = v_payload,
      created_at = now()
    where id = v_existing.id;

    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    v_reply.author_id,
    'reply_reaction',
    v_latest_handle,
    new.reaction || ' · reaccionó a tu comentario',
    v_payload
  );

  return new;
end;
$$;

drop trigger if exists on_reply_reaction_notify on public.forum_reply_likes;
create trigger on_reply_reaction_notify
  after insert on public.forum_reply_likes
  for each row execute function public.notify_on_reply_reaction();

create or replace function public.reply_reaction_users(p_reply_id uuid)
returns table (
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  reaction text,
  reacted_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.user_id,
    p.handle,
    p.display_name,
    p.avatar_url,
    l.reaction,
    l.created_at as reacted_at
  from public.forum_reply_likes l
  join public.profiles p on p.id = l.user_id
  where l.reply_id = p_reply_id
  order by l.created_at desc;
$$;

grant execute on function public.reply_reaction_users(uuid) to authenticated, anon;
