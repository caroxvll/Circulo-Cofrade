-- Cofradero · tendencias reales en Buscar (#hashtags)
-- Ejecutar en SQL Editor (no requiere tablas nuevas)

create or replace function public.fetch_trending_hashtags(p_limit integer default 8)
returns table (
  hashtag text,
  post_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with corpus as (
    select
      coalesce(title, '') || ' ' ||
      coalesce(excerpt, '') || ' ' ||
      coalesce(body, '') as text
    from public.forum_topics
    where status = 'published'
    union all
    select coalesce(r.content, '') as text
    from public.forum_replies r
    join public.forum_topics t on t.id = r.topic_id
    where t.status = 'published'
  ),
  tags as (
    select '#' || (m)[1] as tag
    from corpus,
    lateral regexp_matches(
      text,
      '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
      'g'
    ) as m
  )
  select (array_agg(tag order by tag))[1] as hashtag, count(*)::bigint as post_count
  from tags
  group by lower(tag)
  order by post_count desc, hashtag asc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.fetch_trending_hashtags(integer) to anon, authenticated;
