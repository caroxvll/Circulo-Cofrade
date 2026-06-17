-- Cofradero · aprobación de temas por la Junta (Fase 8g)
-- Ejecutar en SQL Editor

alter table public.forum_topics
  add column if not exists status text not null default 'published'
  check (status in ('pending', 'published', 'rejected'));

-- Temas del seed y existentes siguen publicados
update public.forum_topics
set status = 'published'
where status is null or status = 'published';

-- Nuevos temas: pendientes hasta que la Junta apruebe
alter table public.forum_topics
  alter column status set default 'pending';

drop policy if exists "Temas legibles por todos" on public.forum_topics;

create policy "Temas publicados o propios"
  on public.forum_topics for select
  using (
    status = 'published'
    or author_id = auth.uid()
  );

-- Admin: en Table Editor cambia status a 'published' o 'rejected'
