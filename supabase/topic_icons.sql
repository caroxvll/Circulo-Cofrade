-- Cofradero · iconos y portadas de temas destacados
-- Ejecutar después de pinned_topics.sql. Idempotente.

alter table public.forum_topics
  add column if not exists icon_key text;

alter table public.forum_topics
  add column if not exists cover_image_url text;

update public.forum_topics set icon_key = 'filter_vintage_outlined'
where id = 'circulo-cuaresma';

update public.forum_topics set icon_key = 'account_balance'
where id = 'circulo-semana-santa';

update public.forum_topics set icon_key = 'wb_sunny_outlined'
where id = 'circulo-glorias';

update public.forum_topics set icon_key = 'workspace_premium_outlined'
where id = 'martillo-cambio-capataces';
