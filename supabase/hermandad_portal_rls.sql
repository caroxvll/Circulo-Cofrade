-- Cofradero · Portal hermandad (web): la cuenta oficial lee su tablón
-- Ejecutar después de hermandad_official_posts.sql

drop policy if exists "Hermandad lee su asignación" on public.hermandad_topic_accounts;
create policy "Hermandad lee su asignación"
  on public.hermandad_topic_accounts for select
  using (profile_id = auth.uid());
