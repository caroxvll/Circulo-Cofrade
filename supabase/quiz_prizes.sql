-- Cofradero · premio del mes en Pregunta en vivo
-- Ejecutar en el SQL Editor. Se puede activar o dejar oculto por mes.

create table if not exists public.quiz_month_prizes (
  year_month text primary key
    check (year_month ~ '^[0-9]{4}-[0-9]{2}$'),
  active boolean not null default false,
  sponsor_name text not null default '',
  title text not null default '',
  description text not null default '',
  image_url text,
  address text not null default '',
  claim_until date,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

alter table public.quiz_month_prizes enable row level security;

drop policy if exists "Premios quiz visibles" on public.quiz_month_prizes;
create policy "Premios quiz visibles"
  on public.quiz_month_prizes for select
  using (
    active
    or public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin escribe premios quiz" on public.quiz_month_prizes;
create policy "Admin escribe premios quiz"
  on public.quiz_month_prizes for insert
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Admin actualiza premios quiz" on public.quiz_month_prizes;
create policy "Admin actualiza premios quiz"
  on public.quiz_month_prizes for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Admin borra premios quiz" on public.quiz_month_prizes;
create policy "Admin borra premios quiz"
  on public.quiz_month_prizes for delete
  using (public.is_admin_user(auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quiz-prizes',
  'quiz-prizes',
  true,
  4194304,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Premios quiz lectura publica" on storage.objects;
create policy "Premios quiz lectura publica"
  on storage.objects for select
  using (bucket_id = 'quiz-prizes');

drop policy if exists "Admin sube premios quiz" on storage.objects;
create policy "Admin sube premios quiz"
  on storage.objects for insert
  with check (
    bucket_id = 'quiz-prizes'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin actualiza foto premios quiz" on storage.objects;
create policy "Admin actualiza foto premios quiz"
  on storage.objects for update
  using (
    bucket_id = 'quiz-prizes'
    and public.is_admin_user(auth.uid())
  )
  with check (
    bucket_id = 'quiz-prizes'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin borra foto premios quiz" on storage.objects;
create policy "Admin borra foto premios quiz"
  on storage.objects for delete
  using (
    bucket_id = 'quiz-prizes'
    and public.is_admin_user(auth.uid())
  );
