-- Cofradero · seguir hilos de foro (Fase 1)
-- Ejecutar en SQL Editor después de schema.sql + notifications_triggers.sql

-- Ampliar follows para hilos
alter table public.follows drop constraint if exists follows_target_type_check;
alter table public.follows add constraint follows_target_type_check
  check (target_type in ('hashtag', 'profile', 'topic'));

-- Notificar a seguidores del hilo cuando hay nueva respuesta
create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
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

  -- Avisar al autor del tema (si tiene cuenta y no es el mismo que responde)
  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
    );
  end if;

  -- Avisar a quienes siguen un hashtag que aparece en el tema
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  -- Avisar a quienes siguen el hilo (el autor ya recibe user_reply)
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();
