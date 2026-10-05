-- Cierra la misma brecha que ss_live_likes: DELETE/UPDATE en Realtime
-- deben traer todas las columnas (sobre todo reaction / topic_id).
-- Idempotente. Ejecutar una vez en SQL Editor.

alter table public.forum_reply_likes replica identity full;

-- Por si calendar_events aún no lo tenía (DELETE/UPDATE con oldRecord incompleto).
alter table public.calendar_events replica identity full;
