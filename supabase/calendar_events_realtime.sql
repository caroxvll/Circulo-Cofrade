-- Cofradero · Realtime en eventos del calendario
-- Ejecutar una vez en SQL Editor para que el calendario se actualice al vuelo
-- (aprobaciones de la Junta, publicaciones, etc.).

do $$
begin
  alter publication supabase_realtime add table public.calendar_events;
exception
  when duplicate_object then null;
end $$;

-- DELETE/UPDATE con filtro o lectura de starts_at/status en oldRecord.
alter table public.calendar_events replica identity full;
