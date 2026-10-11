-- Paso 2: quién recibió el aviso del último acto y por qué Paco no.
-- Ejecutar en SQL Editor.

with paco as (
  select id from public.profiles where lower(handle) = 'paco' limit 1
),
last_acto as (
  select id, author_id, official_category, created_at
  from public.forum_replies
  where topic_id = 'lunes-santo-santa-genoveva'
    and coalesce(is_official, false)
    and official_category = 'acto'
  order by created_at desc
  limit 1
),
followers as (
  select
    f.follower_id,
    p.handle,
    f.notify_official_categories,
    f.created_at as followed_at,
    public.notify_pref_enabled(f.follower_id, 'topics') as pref_topics,
    public.is_not_blocked(f.follower_id, (select author_id from last_acto)) as not_blocked,
    f.follower_id is distinct from (select author_id from last_acto) as not_author
  from public.follows f
  join public.profiles p on p.id = f.follower_id
  where f.target_type = 'topic'
    and f.target_id = 'lunes-santo-santa-genoveva'
),
eligible as (
  select *
  from followers
  where pref_topics
    and not_blocked
    and not_author
    and (
      notify_official_categories is null
      or 'acto' = any (notify_official_categories)
    )
),
notifs_last_acto as (
  select n.user_id, p.handle, n.id, n.type, n.title, n.created_at, n.payload
  from public.notifications n
  join public.profiles p on p.id = n.user_id
  where n.payload->>'replyId' = (select id::text from last_acto)
     or n.payload->>'dedupeKey' = 'hermandad_reply:' || (select id::text from last_acto)
),
job as (
  select *
  from public.notification_dispatch_jobs
  where source_id = (select id::text from last_acto)
  limit 1
)
select jsonb_pretty(
  jsonb_build_object(
    'last_acto', (select to_jsonb(last_acto) from last_acto),
    'job', (select to_jsonb(job) from job),
    'followers', coalesce((select jsonb_agg(to_jsonb(followers)) from followers), '[]'::jsonb),
    'eligible', coalesce((select jsonb_agg(to_jsonb(eligible)) from eligible), '[]'::jsonb),
    'eligible_count', (select count(*) from eligible),
    'paco_eligible', exists (
      select 1 from eligible e join paco p on p.id = e.follower_id
    ),
    'notifs_del_acto', coalesce((select jsonb_agg(to_jsonb(notifs_last_acto)) from notifs_last_acto), '[]'::jsonb),
    'paco_en_notifs', exists (
      select 1 from notifs_last_acto n join paco p on p.id = n.user_id
    )
  )
);
