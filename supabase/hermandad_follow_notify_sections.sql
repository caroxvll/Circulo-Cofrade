-- Cofradero · avisos por sección al seguir una hermandad
-- Ejecutar después de hermandad_official_notify.sql

alter table public.follows
  add column if not exists notify_official_categories text[];

comment on column public.follows.notify_official_categories is
  'Tablones hermandad: null = todas las secciones; array de noticia|culto|acto|patrimonio';

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_handle text;
  v_section text;
  v_excerpt text;
  v_category text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_category := coalesce(new.official_category, 'noticia');

  if v_topic.forum_id = 'hermandades'
     and coalesce(new.is_official, false) then
    v_section := public.official_category_label(new.official_category);
    v_excerpt := left(
      regexp_replace(coalesce(new.content, ''), '\s+', ' ', 'g'),
      90
    );

    insert into public.notifications (user_id, type, title, subtitle, payload)
    select
      f.follower_id,
      'topic_activity',
      'Nueva publicación en una hermandad que sigues',
      v_section || ' · ' || left(v_topic.title, 70),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text,
        'officialCategory', v_category
      )
    from public.follows f
    where f.target_type = 'topic'
      and f.target_id = v_topic.id
      and f.follower_id is distinct from new.author_id
      and public.notify_pref_enabled(f.follower_id, 'topics')
      and public.is_not_blocked(f.follower_id, new.author_id)
      and (
        f.notify_official_categories is null
        or v_category = any (f.notify_official_categories)
      );

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
  end if;

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
