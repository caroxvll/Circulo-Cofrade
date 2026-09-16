-- Cofradero · borrar temas desde Junta (historial de rechazos + Moderar tema en foros)
-- Ejecutar después de topic_rejection_reason.sql y roles_v2.sql
-- Si ya ejecutaste la versión solo-rejected, vuelve a correr este script.

drop policy if exists "Junta borra temas rechazados" on public.forum_topics;
drop policy if exists "Junta borra temas" on public.forum_topics;
create policy "Junta borra temas"
  on public.forum_topics for delete
  using (public.can_moderate_topic(auth.uid(), id));
