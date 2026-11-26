-- Origen / crédito de las fotos (copyright) en calendario y temas.
-- Ejecutar en SQL Editor PRE y PROD.

alter table public.calendar_events
  add column if not exists cover_image_credit text;

alter table public.forum_topics
  add column if not exists cover_image_credit text;

alter table public.calendar_events
  drop constraint if exists calendar_events_cover_image_credit_check;

alter table public.calendar_events
  add constraint calendar_events_cover_image_credit_check
  check (cover_image_credit is null or char_length(cover_image_credit) <= 160);

alter table public.forum_topics
  drop constraint if exists forum_topics_cover_image_credit_check;

alter table public.forum_topics
  add constraint forum_topics_cover_image_credit_check
  check (cover_image_credit is null or char_length(cover_image_credit) <= 160);
