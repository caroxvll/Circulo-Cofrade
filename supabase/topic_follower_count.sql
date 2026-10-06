-- Cofradero · conteo público de seguidores de un hilo / tablón
-- RLS en follows solo deja ver filas propias (follower_id = auth.uid()),
-- así que un SELECT directo no refleja el total real del tablón.
-- Este RPC (security definer) solo expone el número, no quién sigue.

create or replace function public.count_topic_followers(p_topic_id text)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint
  from public.follows
  where target_type = 'topic'
    and target_id = p_topic_id;
$$;

grant execute on function public.count_topic_followers(text) to anon, authenticated;

comment on function public.count_topic_followers(text) is
  'Devuelve el nº de seguidores de un topic/tablón sin filtrar por RLS.';
