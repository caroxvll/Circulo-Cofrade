-- Cofradero · Realtime en temas y respuestas del foro
-- Ejecutar una vez en SQL Editor.
-- Permite que quien esté en un foro/hilo vea temas nuevos (publicados)
-- y comentarios nuevos sin tirar para refrescar.

-- Replica identity FULL: filtros por forum_id / topic_id también en DELETE/UPDATE.
alter table public.forum_topics replica identity full;
alter table public.forum_replies replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.forum_topics;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_replies;
exception
  when duplicate_object then null;
end $$;
