-- Cofradeo · avisar a seguidores del perfil cuando una hermandad publica oficialmente
-- Ejecutar después de: notification_social.sql (o mention_reply_scroll.sql),
-- hermandad_official_posts.sql y push_webhook_trigger.sql si usas FCM.
--
-- Comportamiento:
-- · Publicación oficial en foro hermandades (inmediata o programada) → user_post
--   a quien sigue el perfil de la cuenta oficial (notify_profiles).
-- · Si además sigue el tablón (topic), solo recibe topic_activity (evita duplicado).

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
  v_handle text;
  v_author record;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_topic_text := lower(
    regexp_replace(
      coalesce(v_topic.title, '') || ' ' ||
      coalesce(v_topic.excerpt, '') || ' ' ||
      coalesce(v_topic.body, ''),
      '[\s#]+',
      '',
      'g'
    )
  );

  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  -- Seguidores de la cuenta oficial en publicaciones de hermandad
  if coalesce(new.is_official, false)
     and v_topic.forum_id = 'hermandades'
     and new.author_id is not null then
    select display_name, handle
    into v_author
    from public.profiles
    where id = new.author_id;

    if found then
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        f.follower_id,
        'user_post',
        coalesce(v_author.display_name, '@' || v_author.handle) || ' publicó',
        left(coalesce(nullif(trim(new.content), ''), v_topic.title), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'replyId', new.id::text,
          'profileId', new.author_id::text
        )
      from public.follows f
      where f.target_type = 'profile'
        and f.target_id = new.author_id::text
        and f.follower_id is distinct from new.author_id
        and public.notify_pref_enabled(f.follower_id, 'profiles')
        and public.is_not_blocked(f.follower_id, new.author_id)
        and not exists (
          select 1
          from public.follows tf
          where tf.follower_id = f.follower_id
            and tf.target_type = 'topic'
            and tf.target_id = v_topic.id
        );
    end if;
  end if;

  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();
