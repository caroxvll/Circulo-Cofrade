-- Cofradeo · Realtime en avisos de ensayos (Cuaresma)
-- Ejecutar una vez en SQL Editor.

alter table public.event_live_updates replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.event_live_updates;
exception
  when duplicate_object then null;
end $$;
