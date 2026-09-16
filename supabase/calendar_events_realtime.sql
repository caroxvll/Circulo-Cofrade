-- Cofradero · Realtime en eventos del calendario
-- Ejecutar una vez en SQL Editor para que el calendario se actualice al vuelo
-- (aprobaciones de la Junta, publicaciones, etc.).

do $$
begin
  alter publication supabase_realtime add table public.calendar_events;
exception
  when duplicate_object then null;
end $$;
