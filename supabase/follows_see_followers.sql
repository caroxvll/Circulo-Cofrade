-- Cofradero · permitir ver quién te sigue (follows → perfil)
-- Ejecutar en SQL Editor
--
-- Antes solo podías leer filas donde tú eres follower_id.
-- Ahora también puedes SELECT las que te tienen como target (profile).

drop policy if exists "Perfil ve sus seguidores" on public.follows;
create policy "Perfil ve sus seguidores"
  on public.follows for select
  using (
    target_type = 'profile'
    and target_id = auth.uid()::text
  );
