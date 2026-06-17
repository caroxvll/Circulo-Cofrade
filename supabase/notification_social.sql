-- Cofradero · user_post, menciones @handle y preferencias in-app (Opción B)
-- Ejecutar en SQL Editor después de schema.sql, notifications_triggers.sql y topic_follows.sql

-- ---------------------------------------------------------------------------
-- Preferencias (tabla compartida con push Fase 9)
-- ---------------------------------------------------------------------------
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  notify_hashtags boolean not null default true,
  notify_profiles boolean not null default true,
  notify_topics boolean not null default true,
  notify_mentions boolean not null default true,
  notify_followers boolean not null default false,
  notify_calendar boolean not null default false,
  push_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences
  add column if not exists notify_topics boolean not null default true;

alter table public.notification_preferences enable row level security;

drop policy if exists "Usuario lee y edita sus preferencias"
  on public.notification_preferences;
create policy "Usuario lee y edita sus preferencias"
  on public.notification_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into public.notification_preferences (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

create or replace function public.handle_new_profile_preferences()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created_preferences on public.profiles;
create trigger on_profile_created_preferences
  after insert on public.profiles
  for each row execute function public.handle_new_profile_preferences();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
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
    else true
  end;
$$;

create or replace function public.is_not_blocked(p_viewer_id uuid, p_author_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select not exists (
    select 1
    from public.blocks b
    where b.blocker_id = p_viewer_id
      and b.blocked_id = p_author_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Seguidores del autor cuando se publica un tema
-- ---------------------------------------------------------------------------
create or replace function public.notify_followers_on_topic_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author record;
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  if new.author_id is null then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select handle, display_name
  into v_author
  from public.profiles
  where id = new.author_id;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'user_post',
    coalesce(v_author.display_name, '@' || v_author.handle) || ' publicó',
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id,
      'profileId', new.author_id::text
    )
  from public.follows f
  where f.target_type = 'profile'
    and f.target_id = new.author_id::text
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'profiles')
    and public.is_not_blocked(f.follower_id, new.author_id);

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_followers on public.forum_topics;
create trigger on_topic_published_notify_followers
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_followers_on_topic_published();

-- ---------------------------------------------------------------------------
-- Seguidores de hashtag cuando se publica un tema nuevo
-- ---------------------------------------------------------------------------
create or replace function public.notify_hashtag_followers_on_topic_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nueva conversación en ' || f.target_id,
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and (
      new.author_id is null
      or public.is_not_blocked(f.follower_id, new.author_id)
    )
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(new.title, '') || ' ' ||
        coalesce(new.excerpt, '') || ' ' ||
        coalesce(new.body, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_hashtags on public.forum_topics;
create trigger on_topic_published_notify_hashtags
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_hashtag_followers_on_topic_published();

-- ---------------------------------------------------------------------------
-- Respuestas: hashtags, hilos, autor del tema, menciones @handle
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_handle text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  -- Autor del tema (siempre, salvo auto-respuesta)
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

  -- Hashtags seguidos
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
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(v_topic.title, '') || ' ' ||
        coalesce(v_topic.excerpt, '') || ' ' ||
        coalesce(v_topic.body, '') || ' ' ||
        coalesce(new.content, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  -- Hilos seguidos
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

  -- Menciones @handle en el texto de la respuesta
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

-- ---------------------------------------------------------------------------
-- Nuevo seguidor (respeta preferencia notify_followers)
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_profile_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower record;
begin
  if new.target_type <> 'profile' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  if not public.notify_pref_enabled(new.target_id::uuid, 'followers') then
    return new;
  end if;

  select display_name, handle
  into v_follower
  from public.profiles
  where id = new.follower_id;

  if not found then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    new.target_id::uuid,
    'new_follower',
    'Nuevo seguidor',
    coalesce(v_follower.display_name, v_follower.handle) || ' empezó a seguirte',
    jsonb_build_object('profileId', new.follower_id::text)
  );

  return new;
end;
$$;

drop trigger if exists on_profile_follow_notify on public.follows;
create trigger on_profile_follow_notify
  after insert on public.follows
  for each row execute function public.notify_on_profile_follow();
