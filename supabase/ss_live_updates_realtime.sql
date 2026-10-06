-- Cofradeo · Realtime en avisos SS en directo
-- Ejecutar una vez en SQL Editor para que el feed se actualice al vuelo.
-- Gate (ss_live_settings / ss_liturgical_days) y engagement ya van en
-- ss_liturgical_days.sql / ss_live_engagement.sql.

alter table public.ss_live_updates replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.ss_live_updates;
exception
  when duplicate_object then null;
end $$;
