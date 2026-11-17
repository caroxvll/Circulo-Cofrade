-- Diagnóstico: ¿por qué @paco no recibe avisos de Santa Genoveva?
-- Ejecutar en Supabase → SQL Editor y revisar el resultado.

with paco as (
  select id, handle
  from public.profiles
  where lower(handle) in ('paco', '@paco')
  limit 1
),
genoveva as (
  select t.id, t.title, t.forum_id, t.status
  from public.forum_topics t
  where t.forum_id = 'hermandades'
    and (
      t.id ilike '%santa-genoveva%'
      or t.title ilike '%santa genoveva%'
    )
),
follow_row as (
  select
    f.follower_id,
    f.target_id,
    f.notify_official_categories,
    f.created_at
  from public.follows f
  join paco p on p.id = f.follower_id
  where f.target_type = 'topic'
    and f.target_id in (select id from genoveva)
),
recent_official as (
  select
    r.id,
    r.topic_id,
    r.official_category,
    r.is_official,
    r.created_at,
    left(r.content, 80) as content_preview
  from public.forum_replies r
  where r.topic_id in (select id from genoveva)
    and coalesce(r.is_official, false) = true
  order by r.created_at desc
  limit 5
),
notif_for_paco as (
  select n.id, n.type, n.title, n.created_at, n.payload
  from public.notifications n
  join paco p on p.id = n.user_id
  where n.created_at > now() - interval '7 days'
  order by n.created_at desc
  limit 20
),
dispatch_jobs as (
  select
    j.id,
    j.kind,
    j.status,
    j.audience_target_id,
    j.audience_official_category,
    j.processed_count,
    j.error_message,
    j.created_at
  from public.notification_dispatch_jobs j
  where j.audience_target_id in (select id from genoveva)
     or j.title ilike '%hermandad%'
  order by j.created_at desc
  limit 10
)
select jsonb_pretty(
  jsonb_build_object(
    'paco', (select to_jsonb(paco) from paco),
    'tablones_genoveva', coalesce((select jsonb_agg(to_jsonb(genoveva)) from genoveva), '[]'::jsonb),
    'follow_de_paco', coalesce((select jsonb_agg(to_jsonb(follow_row)) from follow_row), '[]'::jsonb),
    'follow_ok', exists (select 1 from follow_row),
    'categorias_avisos', (
      select case
        when not exists (select 1 from follow_row) then 'NO_SIGUE_EL_TABLON'
        when (select notify_official_categories from follow_row limit 1) is null then 'TODAS'
        when cardinality((select notify_official_categories from follow_row limit 1)) = 0 then 'NINGUNA (bloquea todos los avisos)'
        else array_to_string(
          (select notify_official_categories from follow_row limit 1),
          ', '
        )
      end
    ),
    'ultimos_oficiales', coalesce((select jsonb_agg(to_jsonb(recent_official)) from recent_official), '[]'::jsonb),
    'notificaciones_paco_7d', coalesce((select jsonb_agg(to_jsonb(notif_for_paco)) from notif_for_paco), '[]'::jsonb),
    'jobs_dispatch', coalesce((select jsonb_agg(to_jsonb(dispatch_jobs)) from dispatch_jobs), '[]'::jsonb),
    'paco_entraria_en_acto', (
      select exists (
        select 1
        from follow_row f
        where f.notify_official_categories is null
           or 'acto' = any (f.notify_official_categories)
      )
    )
  )
);
