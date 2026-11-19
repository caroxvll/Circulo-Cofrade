-- Cofradeo · el admin y la Junta pueden borrar un aviso de un evento de Cuaresma.
-- Idempotente. Ejecutar en SQL Editor después de event_live_updates.sql.
-- Quien escribió el aviso sigue pudiendo borrarlo con la policy anterior.

drop policy if exists "Staff borra aviso en vivo" on public.event_live_updates;
create policy "Staff borra aviso en vivo"
  on public.event_live_updates for delete
  to authenticated
  using (
    public.is_admin_user(auth.uid())
    or public.is_junta_member(auth.uid())
  );
