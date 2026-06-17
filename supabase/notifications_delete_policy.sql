-- Cofradero · permitir borrar notificaciones propias (Fase 8e)
-- Ejecutar en SQL Editor si aún no tienes política DELETE

drop policy if exists "Usuario borra sus notificaciones" on public.notifications;
create policy "Usuario borra sus notificaciones"
  on public.notifications for delete
  using (auth.uid() = user_id);
