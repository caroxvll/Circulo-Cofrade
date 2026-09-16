-- Cofradero · Realtime en asignaciones de moderadores
-- Ejecutar una vez en SQL Editor para que los permisos se actualicen al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.forum_moderators;
exception
  when duplicate_object then null;
end $$;
