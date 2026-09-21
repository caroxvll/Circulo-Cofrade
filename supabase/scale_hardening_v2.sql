-- Cofradero · Escala v2: cola para TODO fan-out masivo
-- Ejecutar DESPUÉS de scale_hardening_v1.sql (corregido).
-- Idempotente.
--
-- Qué pasa a la cola (Cron process_notification_dispatch):
--   · Seguidores de Noticias
--   · Seguidores de un hilo (nueva respuesta / post oficial hermandad)
--   · Seguidores de hashtag (tema o comentario)
--   · Seguidores de un perfil (publica tema)
--   · Calendario publicado (quien tiene notify_calendar)
--   · Quiz en vivo (quien tiene notify_quiz)
--
-- Sigue en inmediato (1 persona / pocos):
--   · Respuesta al autor del hilo, @menciones, reacciones, nuevo seguidor, junta
--
-- Cron (igual que v1):
--   select public.process_notification_dispatch(500);

-- =============================================================================
-- 1) Ampliar la cola
-- =============================================================================
alter table public.notification_dispatch_jobs
  drop constraint if exists notification_dispatch_jobs_kind_check;

alter table public.notification_dispatch_jobs
  add column if not exists notif_type text,
  add column if not exists audience_mode text,
  add column if not exists audience_target_type text,
  add column if not exists audience_target_id text,
  add column if not exists audience_pref text,
  add column if not exists audience_hashtags text[],
  add column if not exists audience_official_category text,
  add column if not exists dedupe_key text;

-- Migrar jobs viejos de Noticias
update public.notification_dispatch_jobs
set
  notif_type = coalesce(notif_type, 'news_published'),
  audience_mode = coalesce(audience_mode, 'follows'),
  audience_target_type = coalesce(audience_target_type, 'forum'),
  audience_target_id = coalesce(audience_target_id, 'noticias'),
  audience_pref = coalesce(audience_pref, 'news'),
  dedupe_key = coalesce(dedupe_key, 'news:' || source_id)
where kind = 'news_published';

alter table public.notification_dispatch_jobs
  alter column notif_type set default 'news_published',
  alter column audience_mode set default 'follows';

update public.notification_dispatch_jobs
set notif_type = 'news_published'
where notif_type is null;

update public.notification_dispatch_jobs
set audience_mode = 'follows'
where audience_mode is null;

alter table public.notification_dispatch_jobs
  alter column notif_type set not null,
  alter column audience_mode set not null;

alter table public.notification_dispatch_jobs
  drop constraint if exists notification_dispatch_jobs_audience_mode_check;

alter table public.notification_dispatch_jobs
  add constraint notification_dispatch_jobs_audience_mode_check
  check (audience_mode in ('follows', 'follows_hashtags', 'pref'));

alter table public.notification_dispatch_jobs
  drop constraint if exists notification_dispatch_jobs_kind_check;

alter table public.notification_dispatch_jobs
  add constraint notification_dispatch_jobs_kind_check
  check (kind in (
    'news_published',
    'topic_followers',
    'hashtag_followers',
    'profile_followers',
    'calendar_broadcast',
    'quiz_broadcast'
  ));

-- =============================================================================
-- 2) Helper de encolado
-- =============================================================================
create or replace function public.enqueue_notification_job(
  p_kind text,
  p_source_id text,
  p_title text,
  p_subtitle text,
  p_payload jsonb,
  p_author_id uuid,
  p_notif_type text,
  p_audience_mode text,
  p_audience_target_type text default null,
  p_audience_target_id text default null,
  p_audience_pref text default null,
  p_audience_hashtags text[] default null,
  p_audience_official_category text default null,
  p_dedupe_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.notification_dispatch_jobs (
    kind,
    source_id,
    title,
    subtitle,
    payload,
    author_id,
    notif_type,
    audience_mode,
    audience_target_type,
    audience_target_id,
    audience_pref,
    audience_hashtags,
    audience_official_category,
    dedupe_key
  ) values (
    p_kind,
    p_source_id,
    p_title,
    p_subtitle,
    coalesce(p_payload, '{}'::jsonb),
    p_author_id,
    p_notif_type,
    p_audience_mode,
    p_audience_target_type,
    p_audience_target_id,
    p_audience_pref,
    p_audience_hashtags,
    p_audience_official_category,
    p_dedupe_key
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.enqueue_notification_job(
  text, text, text, text, jsonb, uuid, text, text, text, text, text, text[], text, text
) from public;
grant execute on function public.enqueue_notification_job(
  text, text, text, text, jsonb, uuid, text, text, text, text, text, text[], text, text
) to service_role;

-- =============================================================================
-- 3) Procesador genérico (mismo Cron de siempre)
-- =============================================================================
create or replace function public.process_notification_dispatch(p_limit int default 500)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.notification_dispatch_jobs%rowtype;
  batch_limit int := least(greatest(coalesce(p_limit, 500), 50), 2000);
  inserted int := 0;
  last_created timestamptz;
  last_follower uuid;
  v_payload jsonb;
begin
  perform set_config('row_security', 'off', true);

  select * into job
  from public.notification_dispatch_jobs
  where status in ('pending', 'processing')
  order by created_at
  for update skip locked
  limit 1;

  if not found then
    return jsonb_build_object('ok', true, 'processed', 0, 'reason', 'idle');
  end if;

  update public.notification_dispatch_jobs
  set status = 'processing', updated_at = now()
  where id = job.id;

  v_payload := coalesce(job.payload, '{}'::jsonb);
  if job.dedupe_key is not null then
    v_payload := v_payload || jsonb_build_object('dedupeKey', job.dedupe_key);
  end if;

  if job.audience_mode = 'pref' then
    with candidates as (
      select
        p.id as follower_id,
        p.created_at as follow_created_at
      from public.profiles p
      where p.suspended_at is null
        and p.id is distinct from job.author_id
        and public.notify_pref_enabled(p.id, coalesce(job.audience_pref, 'calendar'))
        and (
          job.cursor_follower_id is null
          or (p.created_at, p.id) > (job.cursor_created_at, job.cursor_follower_id)
        )
        and (
          job.dedupe_key is null
          or not exists (
            select 1 from public.notifications n
            where n.user_id = p.id
              and n.type = job.notif_type
              and n.payload->>'dedupeKey' = job.dedupe_key
          )
        )
      order by p.created_at, p.id
      limit batch_limit
    ),
    inserted_rows as (
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select c.follower_id, job.notif_type, job.title, job.subtitle, v_payload
      from candidates c
      returning 1
    )
    select
      (select count(*)::int from inserted_rows),
      (select follow_created_at from candidates order by follow_created_at desc, follower_id desc limit 1),
      (select follower_id from candidates order by follow_created_at desc, follower_id desc limit 1)
    into inserted, last_created, last_follower;

  elsif job.audience_mode = 'follows_hashtags' then
    with candidates as (
      select
        x.follower_id,
        x.follow_created_at
      from (
        select
          f.follower_id,
          min(f.created_at) as follow_created_at
        from public.follows f
        join public.profiles p on p.id = f.follower_id
        where f.target_type = 'hashtag'
          and lower(f.target_id) = any (
            select lower(t) from unnest(coalesce(job.audience_hashtags, array[]::text[])) as t
          )
          and p.suspended_at is null
          and f.follower_id is distinct from job.author_id
          and public.notify_pref_enabled(f.follower_id, coalesce(job.audience_pref, 'hashtags'))
          and (
            job.author_id is null
            or public.is_not_blocked(f.follower_id, job.author_id)
          )
          and (
            job.cursor_follower_id is null
            or f.follower_id > job.cursor_follower_id
          )
          and (
            job.dedupe_key is null
            or not exists (
              select 1 from public.notifications n
              where n.user_id = f.follower_id
                and n.type = job.notif_type
                and n.payload->>'dedupeKey' = job.dedupe_key
            )
          )
        group by f.follower_id
      ) x
      order by x.follower_id
      limit batch_limit
    ),
    inserted_rows as (
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select c.follower_id, job.notif_type, job.title, job.subtitle, v_payload
      from candidates c
      returning 1
    )
    select
      (select count(*)::int from inserted_rows),
      (select follow_created_at from candidates order by follower_id desc limit 1),
      (select follower_id from candidates order by follower_id desc limit 1)
    into inserted, last_created, last_follower;

  else
    -- follows (forum / topic / profile)
    with candidates as (
      select
        f.follower_id,
        f.created_at as follow_created_at
      from public.follows f
      join public.profiles p on p.id = f.follower_id
      where f.target_type = job.audience_target_type
        and f.target_id = job.audience_target_id
        and p.suspended_at is null
        and f.follower_id is distinct from job.author_id
        and (
          job.audience_pref is null
          or public.notify_pref_enabled(f.follower_id, job.audience_pref)
        )
        and (
          job.author_id is null
          or public.is_not_blocked(f.follower_id, job.author_id)
        )
        and (
          job.audience_official_category is null
          or f.notify_official_categories is null
          or job.audience_official_category = any (f.notify_official_categories)
        )
        and (
          job.cursor_created_at is null
          or (f.created_at, f.follower_id) > (job.cursor_created_at, job.cursor_follower_id)
        )
        and (
          job.dedupe_key is null
          or not exists (
            select 1 from public.notifications n
            where n.user_id = f.follower_id
              and n.type = job.notif_type
              and n.payload->>'dedupeKey' = job.dedupe_key
          )
        )
      order by f.created_at, f.follower_id
      limit batch_limit
    ),
    inserted_rows as (
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select c.follower_id, job.notif_type, job.title, job.subtitle, v_payload
      from candidates c
      returning 1
    )
    select
      (select count(*)::int from inserted_rows),
      (select follow_created_at from candidates order by follow_created_at desc, follower_id desc limit 1),
      (select follower_id from candidates order by follow_created_at desc, follower_id desc limit 1)
    into inserted, last_created, last_follower;
  end if;

  if coalesce(inserted, 0) = 0 then
    update public.notification_dispatch_jobs
    set status = 'done', updated_at = now(), error_message = null
    where id = job.id;
    return jsonb_build_object('ok', true, 'jobId', job.id, 'processed', 0, 'status', 'done');
  end if;

  update public.notification_dispatch_jobs
  set
    cursor_created_at = last_created,
    cursor_follower_id = last_follower,
    processed_count = processed_count + inserted,
    updated_at = now(),
    status = case when inserted < batch_limit then 'done' else 'processing' end,
    error_message = null
  where id = job.id;

  return jsonb_build_object(
    'ok', true,
    'jobId', job.id,
    'processed', inserted,
    'status', case when inserted < batch_limit then 'done' else 'processing' end,
    'kind', job.kind
  );
exception
  when others then
    update public.notification_dispatch_jobs
    set status = 'failed', error_message = left(sqlerrm, 400), updated_at = now()
    where id = job.id;
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.process_notification_dispatch(int) from public;
grant execute on function public.process_notification_dispatch(int) to service_role;

-- =============================================================================
-- 4) Noticias → cola (actualiza enqueue v1)
-- =============================================================================
create or replace function public.enqueue_noticias_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id is distinct from 'noticias' then
    return new;
  end if;
  if new.status <> 'published' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  perform public.enqueue_notification_job(
    'news_published',
    new.id,
    'Nueva noticia',
    left(new.title, 80),
    jsonb_build_object('forumId', new.forum_id, 'topicId', new.id),
    new.author_id,
    'news_published',
    'follows',
    'forum',
    'noticias',
    'news',
    null,
    null,
    'news:' || new.id
  );

  return new;
end;
$$;

drop trigger if exists on_noticias_published_notify on public.forum_topics;
create trigger on_noticias_published_notify
  after insert or update of status on public.forum_topics
  for each row execute function public.enqueue_noticias_notify();

-- =============================================================================
-- 5) Seguidores de perfil al publicar tema → cola
-- =============================================================================
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
  -- Noticias ya tiene su propio job
  if new.forum_id = 'noticias' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select handle, display_name into v_author
  from public.profiles where id = new.author_id;

  perform public.enqueue_notification_job(
    'profile_followers',
    new.id,
    coalesce(v_author.display_name, '@' || v_author.handle) || ' publicó',
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id,
      'profileId', new.author_id::text
    ),
    new.author_id,
    'user_post',
    'follows',
    'profile',
    new.author_id::text,
    'profiles',
    null,
    null,
    'user_post:' || new.id
  );

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_followers on public.forum_topics;
create trigger on_topic_published_notify_followers
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_followers_on_topic_published();

-- =============================================================================
-- 6) Hashtags al publicar tema → cola
-- =============================================================================
create or replace function public.notify_hashtag_followers_on_topic_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tags text[];
begin
  if new.status <> 'published' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  select array_agg(distinct lower('#' || m[1]))
  into v_tags
  from regexp_matches(
    coalesce(new.title, '') || ' ' ||
    coalesce(new.excerpt, '') || ' ' ||
    coalesce(new.body, ''),
    '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
    'g'
  ) as m;

  if v_tags is null or cardinality(v_tags) = 0 then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  perform public.enqueue_notification_job(
    'hashtag_followers',
    new.id,
    'Nueva conversación en hashtag',
    left(new.title, 80),
    jsonb_build_object('forumId', new.forum_id, 'topicId', new.id),
    new.author_id,
    'hashtag_activity',
    'follows_hashtags',
    null,
    null,
    'hashtags',
    v_tags,
    null,
    'hashtag_topic:' || new.id
  );

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_hashtags on public.forum_topics;
create trigger on_topic_published_notify_hashtags
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_hashtag_followers_on_topic_published();

-- =============================================================================
-- 7) Respuestas en hilo: fan-out a cola; autor + menciones sync
-- =============================================================================
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
  v_category text;
  v_tags text[];
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

  -- Post oficial hermandad → seguidores del tablón (cola)
  if v_topic.forum_id = 'hermandades'
     and coalesce(new.is_official, false) then
    v_section := public.official_category_label(new.official_category);

    perform public.enqueue_notification_job(
      'topic_followers',
      new.id::text,
      'Nueva publicación en una hermandad que sigues',
      v_section || ' · ' || left(v_topic.title, 70),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text,
        'officialCategory', v_category
      ),
      new.author_id,
      'topic_activity',
      'follows',
      'topic',
      v_topic.id,
      'topics',
      null,
      v_category,
      'hermandad_reply:' || new.id::text
    );

    -- menciones: sync (pocos)
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

  -- Autor del hilo: 1 persona → sync
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

  -- Hashtags en respuesta → cola
  select array_agg(distinct lower('#' || m[1]))
  into v_tags
  from regexp_matches(
    coalesce(v_topic.title, '') || ' ' ||
    coalesce(v_topic.excerpt, '') || ' ' ||
    coalesce(v_topic.body, '') || ' ' ||
    coalesce(new.content, ''),
    '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
    'g'
  ) as m;

  if v_tags is not null and cardinality(v_tags) > 0 then
    perform public.enqueue_notification_job(
      'hashtag_followers',
      new.id::text,
      'Nuevo comentario en hashtag',
      left(v_topic.title, 80) || ' · ' || new.author_handle,
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      ),
      new.author_id,
      'hashtag_activity',
      'follows_hashtags',
      null,
      null,
      'hashtags',
      v_tags,
      null,
      'hashtag_reply:' || new.id::text
    );
  end if;

  -- Seguidores del hilo → cola
  perform public.enqueue_notification_job(
    'topic_followers',
    new.id::text,
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    ),
    new.author_id,
    'topic_activity',
    'follows',
    'topic',
    v_topic.id,
    'topics',
    null,
    null,
    'topic_reply:' || new.id::text
  );

  -- menciones sync
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

-- =============================================================================
-- 8) Calendario / Quiz → cola (broadcast por preferencia)
-- =============================================================================
create or replace function public.notify_users_on_calendar_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  if new.status <> 'published' then
    return new;
  end if;
  if tg_op = 'UPDATE' and coalesce(old.status, '') = 'published' then
    return new;
  end if;

  v_title := case new.event_type
    when 'procesion' then 'Nueva procesión en el calendario'
    when 'gloria' then 'Nuevo acto de gloria'
    when 'ensayo' then 'Nuevo ensayo en el calendario'
    when 'iguala' then 'Nueva igualá en el calendario'
    when 'concierto' then 'Nuevo concierto cofrade'
    else 'Nuevo aviso del calendario'
  end;

  perform public.enqueue_notification_job(
    'calendar_broadcast',
    new.id::text,
    v_title,
    left(new.title, 80),
    jsonb_build_object(
      'route', '/calendario',
      'eventId', new.id::text,
      'eventType', new.event_type,
      'startsAt', new.starts_at,
      'organizerLabel', new.organizer_label
    ),
    new.created_by,
    'calendar',
    'pref',
    null,
    null,
    'calendar',
    null,
    null,
    'calendar:' || new.id::text
  );

  return new;
end;
$$;

drop trigger if exists on_calendar_published_notify_users on public.calendar_events;
create trigger on_calendar_published_notify_users
  after insert or update of status on public.calendar_events
  for each row execute function public.notify_users_on_calendar_published();

create or replace function public.notify_users_on_quiz_live()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prompt text;
begin
  if new.status <> 'live' then
    return new;
  end if;
  if tg_op = 'UPDATE' and coalesce(old.status, '') = 'live' then
    return new;
  end if;

  select left(prompt, 80) into v_prompt
  from public.quiz_questions
  where id = new.question_id;

  perform public.enqueue_notification_job(
    'quiz_broadcast',
    new.id::text,
    '¡Pregunta en vivo!',
    coalesce(v_prompt, 'Tienes 15 segundos para responder'),
    jsonb_build_object('route', '/quiz', 'roundId', new.id::text),
    null,
    'quiz',
    'pref',
    null,
    null,
    'quiz',
    null,
    null,
    'quiz:' || new.id::text
  );

  return new;
end;
$$;

drop trigger if exists on_quiz_round_live_notify on public.quiz_rounds;
create trigger on_quiz_round_live_notify
  after insert or update of status on public.quiz_rounds
  for each row execute function public.notify_users_on_quiz_live();

comment on function public.process_notification_dispatch(int) is
  'Procesa un job de la cola (Noticias, hilos, hashtags, perfiles, calendario, quiz). Cron cada 1 min.';

notify pgrst, 'reload schema';
