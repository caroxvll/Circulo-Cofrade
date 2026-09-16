-- Cofradeo · título opcional en hero de hubs (SS / Cuaresma…)
-- Ejecutar en SQL Editor. Idempotente.

alter table public.forum_topics
  add column if not exists show_hub_title boolean not null default true;

comment on column public.forum_topics.show_hub_title is
  'Si false, el hub no muestra icono/título sobre la portada (útil cuando la imagen ya lleva marca).';

notify pgrst, 'reload schema';
