-- Cofradeo · enlace evento ↔ tablón de hermandad
-- Idempotente. Ejecutar en SQL Editor (PRE/PROD).

alter table public.calendar_events
  add column if not exists hermandad_topic_id text
    references public.forum_topics (id) on delete set null;

comment on column public.calendar_events.hermandad_topic_id is
  'Tablón oficial (forum_topics.id con forum_id=hermandades). Null = organizador libre / legacy.';

create index if not exists calendar_events_hermandad_topic_id_idx
  on public.calendar_events (hermandad_topic_id)
  where hermandad_topic_id is not null;

notify pgrst, 'reload schema';
