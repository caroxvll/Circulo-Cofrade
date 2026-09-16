-- Cofradero · Realtime en pilares de foro y app_config (hero de FOROS)
-- Ejecutar una vez en SQL Editor para sincronizar portadas/iconos al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.forum_pillars;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.app_config;
exception
  when duplicate_object then null;
end $$;
