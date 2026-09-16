-- Cofradero · Ajustes temas destacados (admin)
-- Ejecutar después de pinned_topics.sql y topic_icons.sql. Idempotente.

alter table public.forum_topics
  add column if not exists is_listed boolean not null default true;

-- Semana Santa es tema fijo del Círculo (el pilar legacy queda oculto).
update public.forum_pillars
set
  is_enabled = false,
  locked_label = 'Se activará en Semana Santa'
where id = 'semana-santa';

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status,
  is_pinned, pin_sort_order, is_system, season_key, icon_key, created_at
) values
  (
    'circulo-semana-santa', 'foro-cofradiero', '@cofradeo',
    'Semana Santa',
    'Todo sobre la Semana Mayor: procesiones, horarios y noticias.',
    'El hilo de la Semana Mayor: procesiones, horarios, itinerarios, avisos y noticias de las jornadas grandes.\n\nCentraliza aquí la conversación cofrade de la Semana Santa en Sevilla.',
    false, 0, 0, 'published',
    true, 2, true, 'semana_santa', 'account_balance', now() - interval '29 days'
  )
on conflict (id) do update set
  forum_id = excluded.forum_id,
  title = excluded.title,
  excerpt = excluded.excerpt,
  body = excluded.body,
  status = excluded.status,
  is_pinned = excluded.is_pinned,
  pin_sort_order = excluded.pin_sort_order,
  is_system = excluded.is_system,
  season_key = excluded.season_key,
  icon_key = excluded.icon_key;

update public.forum_topics
set pin_sort_order = case id
  when 'circulo-cuaresma' then 1
  when 'circulo-semana-santa' then 2
  when 'circulo-glorias' then 3
  when 'martillo-cambio-capataces' then 1
  else pin_sort_order
end
where id in (
  'circulo-cuaresma',
  'circulo-semana-santa',
  'circulo-glorias',
  'martillo-cambio-capataces'
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'topic-covers',
  'topic-covers',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Portadas temas lectura publica" on storage.objects;
create policy "Portadas temas lectura publica"
  on storage.objects for select
  using (bucket_id = 'topic-covers');

drop policy if exists "Staff sube portadas temas" on storage.objects;
create policy "Staff sube portadas temas"
  on storage.objects for insert
  with check (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff actualiza portadas temas" on storage.objects;
create policy "Staff actualiza portadas temas"
  on storage.objects for update
  using (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  )
  with check (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff borra portadas temas" on storage.objects;
create policy "Staff borra portadas temas"
  on storage.objects for delete
  using (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff crea temas fijos" on public.forum_topics;
create policy "Staff crea temas fijos"
  on public.forum_topics for insert
  with check (
    public.is_staff_user(auth.uid())
    and is_system = true
    and is_pinned = true
  );

drop policy if exists "Staff borra temas fijos" on public.forum_topics;
create policy "Staff borra temas fijos"
  on public.forum_topics for delete
  using (
    public.is_staff_user(auth.uid())
    and is_system = true
  );
