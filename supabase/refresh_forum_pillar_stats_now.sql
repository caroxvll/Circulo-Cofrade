-- Cofradero · recalcular contadores de pilares (p. ej. «2 noticias» desfasado)
-- Ejecutar en SQL Editor si la tarjeta del foro no cuadra con los temas reales.

-- Asegura el trigger de sync (idempotente)
drop trigger if exists on_forum_topic_stats on public.forum_topics;
create trigger on_forum_topic_stats
  after insert or update of status or delete on public.forum_topics
  for each row execute function public.refresh_forum_pillar_stats_from_topic();

-- Recalcula todos los foros ahora
do $$
declare
  r record;
begin
  for r in select id from public.forum_pillars loop
    perform public.refresh_forum_pillar_stats(r.id);
  end loop;
end;
$$;

-- Comprobar Noticias:
-- select id, topic_count, message_count from public.forum_pillars where id = 'noticias';
