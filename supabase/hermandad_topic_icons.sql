-- Cofradero · Escudo remoto en tablones de hermandad (forum_topics.icon_image_url)
-- Ejecutar en Supabase → SQL Editor después de topic_icons.sql / hermandad_boards_admin.sql.
-- Idempotente.

alter table public.forum_topics
  add column if not exists icon_image_url text;
