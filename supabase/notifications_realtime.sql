-- Círculo Cofrade · Realtime en la bandeja de notificaciones
-- Ejecutar una vez en SQL Editor para que la app reciba INSERT/UPDATE/DELETE al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception
  when duplicate_object then null;
end $$;

-- Necesario si el canal filtra por user_id (no es la PK).
alter table public.notifications replica identity full;
