-- Cofradero · contador de visitas al abrir un tema
-- Ejecutar en SQL Editor
--
-- ⚠️ Obsoleto: usar topic_views_dedup.sql (1 visita por viewer y día).
-- Se mantiene como referencia histórica del MVP inicial.

create or replace function public.increment_topic_view(p_topic_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.forum_topics
  set view_count = view_count + 1
  where id = p_topic_id;
end;
$$;

grant execute on function public.increment_topic_view(text) to anon, authenticated;
