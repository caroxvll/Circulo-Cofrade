-- Descripción de eventos (subtitle): 240 → 1000 caracteres.
-- Ejecutar en SQL Editor (prod / pre).

alter table public.calendar_events
  drop constraint if exists calendar_events_subtitle_check;

alter table public.calendar_events
  add constraint calendar_events_subtitle_check
  check (char_length(subtitle) <= 1000);
