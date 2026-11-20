-- El admin puede publicar Historias sin sello de Cronista.
-- Idempotente. Ejecutar en SQL Editor (PRE/PROD) después de historias.sql.

create or replace function public.can_publish_historia(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_chronicler(p_user_id)
      or public.is_admin_user(p_user_id);
$$;

grant execute on function public.can_publish_historia(uuid) to authenticated;

drop policy if exists "Cronista publica historia" on public.historias;
create policy "Cronista publica historia"
  on public.historias for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.can_publish_historia(auth.uid())
  );

drop policy if exists "Cronista sube portada historia" on storage.objects;
create policy "Cronista sube portada historia"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'historia-covers'
    and public.can_publish_historia(auth.uid())
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Cronista actualiza portada historia" on storage.objects;
create policy "Cronista actualiza portada historia"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'historia-covers'
    and (
      (
        public.can_publish_historia(auth.uid())
        and (storage.foldername(name))[1] = auth.uid()::text
      )
      or public.is_junta_member(auth.uid())
    )
  );

notify pgrst, 'reload schema';
