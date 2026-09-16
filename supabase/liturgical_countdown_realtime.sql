-- Cofradero · Realtime en configuración de cuenta atrás litúrgica
-- Ejecutar una vez en SQL Editor para sincronizar activar/ocultar al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.liturgical_countdown_settings;
exception
  when duplicate_object then null;
end $$;
