-- Cofradeo · enlace post → evento (mínimo).
-- Preferible ejecutar el paquete completo:
--   orphan_cleanup_and_scheduled_calendar.sql
-- Idempotente.

alter table public.calendar_events
  add column if not exists source_reply_id uuid
    references public.forum_replies (id) on delete set null;

create index if not exists calendar_events_source_reply_id_idx
  on public.calendar_events (source_reply_id)
  where source_reply_id is not null;

comment on column public.calendar_events.source_reply_id is
  'Comunicado oficial (forum_replies) que originó este evento, si aplica.';
