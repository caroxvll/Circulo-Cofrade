-- ¿Qué actos hay en Santa Genoveva y por qué el admin podría no verlos?
select
  r.id,
  r.official_category,
  r.is_official,
  r.deleted_at,
  r.created_at,
  r.author_id,
  p.handle as author_handle,
  left(r.content, 60) as preview,
  case
    when r.deleted_at is not null then 'BORRADO (admin lo oculta; app tampoco debería verlo)'
    when r.is_official and r.official_category = 'acto' then 'VISIBLE acto'
    else 'otro'
  end as estado
from public.forum_replies r
left join public.profiles p on p.id = r.author_id
where r.topic_id = 'lunes-santo-santa-genoveva'
  and (
    coalesce(r.is_official, false) = true
    or r.official_category = 'acto'
  )
order by r.created_at desc
limit 20;
