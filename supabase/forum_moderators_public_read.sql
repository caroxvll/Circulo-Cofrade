-- Cofradero · lectura pública de moderadores de foro
-- Necesario para la ficha «Acerca del foro». Idempotente.
-- Ejecutar si la lista de moderadores se queda cargando o vacía para usuarios normales.

drop policy if exists "Moderadores visibles publicamente" on public.forum_moderators;
create policy "Moderadores visibles publicamente"
  on public.forum_moderators for select
  using (true);
