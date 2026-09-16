-- Cofradero · quién puede proponer preguntas del quiz
-- Ejecutar después de quiz_daily.sql y roles_v2.sql
-- Idempotente.

create table if not exists public.quiz_authors (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  granted_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.quiz_authors enable row level security;

drop policy if exists "Junta lee autores quiz" on public.quiz_authors;
create policy "Junta lee autores quiz"
  on public.quiz_authors for select
  using (
    public.is_admin_user(auth.uid())
    or profile_id = auth.uid()
  );

drop policy if exists "Admin gestiona autores quiz" on public.quiz_authors;
create policy "Admin gestiona autores quiz"
  on public.quiz_authors for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

create or replace function public.can_create_quiz_question(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin_user(p_user_id)
    or exists (
      select 1
      from public.quiz_authors qa
      where qa.profile_id = p_user_id
    );
$$;

-- Sustituye políticas de preguntas: solo autores autorizados (o admin)
drop policy if exists "Junta lee preguntas quiz" on public.quiz_questions;
create policy "Autores y admin leen preguntas quiz"
  on public.quiz_questions for select
  using (public.can_create_quiz_question(auth.uid()));

drop policy if exists "Junta crea preguntas quiz" on public.quiz_questions;
create policy "Autores crean preguntas quiz"
  on public.quiz_questions for insert
  with check (
    public.can_create_quiz_question(auth.uid())
    and created_by = auth.uid()
  );

-- Rondas: autores también pueden leer (panel Junta)
drop policy if exists "Usuarios leen rondas quiz" on public.quiz_rounds;
create policy "Usuarios leen rondas quiz"
  on public.quiz_rounds for select
  using (
    status in ('live', 'closed')
    or public.can_create_quiz_question(auth.uid())
  );

drop policy if exists "Usuario gestiona su respuesta quiz" on public.quiz_answers;
create policy "Usuario gestiona su respuesta quiz"
  on public.quiz_answers for select
  using (
    user_id = auth.uid()
    or public.can_create_quiz_question(auth.uid())
  );
