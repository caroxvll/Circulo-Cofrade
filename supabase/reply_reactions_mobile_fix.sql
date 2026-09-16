-- Cofradero · reaction EXISTE pero el móvil falla al guardar (42703)
-- Causa típica: trigger de notificación busca notify_reactions (u otra col) y tumba el INSERT.
-- Ejecutar entero en SQL Editor del proyecto de env.json.

alter table public.notification_preferences
  add column if not exists notify_reactions boolean not null default true;

alter table public.notification_preferences
  add column if not exists notify_calendar boolean not null default true;

alter table public.notification_preferences
  add column if not exists notify_quiz boolean not null default true;

-- Preferencias: no fallar si falta alguna columna
create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_val boolean;
begin
  if p_pref = 'hashtags' then
    select coalesce(notify_hashtags, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'profiles' then
    select coalesce(notify_profiles, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'topics' then
    select coalesce(notify_topics, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'mentions' then
    select coalesce(notify_mentions, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'followers' then
    select coalesce(notify_followers, false) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'reactions' then
    select coalesce(notify_reactions, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'calendar' then
    select coalesce(notify_calendar, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'quiz' then
    select coalesce(notify_quiz, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  else
    return true;
  end if;

  if v_val is null then
    return p_pref <> 'followers';
  end if;
  return v_val;
exception
  when undefined_column then
    return p_pref <> 'followers';
  when others then
    return p_pref <> 'followers';
end;
$$;

-- Aviso de reacción: NUNCA debe impedir el upsert
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

    select id, payload, title
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
    else
      insert into public.notifications (user_id, type, title, subtitle, payload)
      values (
        v_reply.author_id,
        'reply_reaction',
        v_latest_handle,
        new.reaction || ' · reaccionó a tu comentario',
        v_payload
      );
    end if;
  exception
    when others then
      raise warning 'notify_on_reply_reaction: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists on_reply_reaction_notify on public.forum_reply_likes;
create trigger on_reply_reaction_notify
  after insert on public.forum_reply_likes
  for each row execute function public.notify_on_reply_reaction();

notify pgrst, 'reload schema';
