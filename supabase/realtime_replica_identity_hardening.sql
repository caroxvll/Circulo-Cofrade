-- Cierra brechas Realtime: DELETE/UPDATE filtrados por columnas no-PK.
-- Idempotente. Ejecutar una vez (o varias) en SQL Editor.

alter table public.notifications replica identity full;
alter table public.forum_reply_likes replica identity full;
alter table public.calendar_events replica identity full;
alter table public.ss_live_update_likes replica identity full;
alter table public.ss_live_update_replies replica identity full;

-- Comprobar (opcional):
-- select c.relname, c.relreplident
-- from pg_class c join pg_namespace n on n.oid = c.relnamespace
-- where n.nspname = 'public'
--   and c.relname in (
--     'notifications','forum_reply_likes','calendar_events',
--     'ss_live_update_likes','ss_live_update_replies'
--   );
-- Esperado: relreplident = 'f'
