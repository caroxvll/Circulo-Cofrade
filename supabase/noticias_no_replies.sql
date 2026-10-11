-- Cofradeo · Noticias sin comentarios (solo lectura editorial)
-- Ejecutar en SQL Editor (idempotente).

drop policy if exists "Usuarios autenticados responden" on public.forum_replies;
create policy "Usuarios autenticados responden"
  on public.forum_replies for insert
  with check (
    auth.uid() is not null
    and author_id = auth.uid()
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
    and not exists (
      select 1
      from public.forum_topics t
      where t.id = topic_id
        and t.forum_id = 'noticias'
    )
  );

comment on policy "Usuarios autenticados responden" on public.forum_replies is
  'Insert permitido salvo en temas del foro noticias (editorial sin comentarios).';

notify pgrst, 'reload schema';
