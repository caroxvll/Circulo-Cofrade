-- Cofradero · borrar preguntas (+ media) y config Temporada cofrade
-- Ejecutar tras quiz_daily / quiz_fixes / quiz_audio

-- Temporada cofrade (visible en idle del quiz)
insert into public.app_config (key, value)
values
  ('quiz_season_starts_on', ''),
  ('quiz_season_message', ''),
  -- Acceso público a Pregunta en vivo (FAB + rutas /quiz)
  ('quiz_live_visible', 'true')
on conflict (key) do nothing;

-- Admin puede borrar preguntas
drop policy if exists "Admin borra preguntas quiz" on public.quiz_questions;
create policy "Admin borra preguntas quiz"
  on public.quiz_questions for delete
  using (public.is_admin_user(auth.uid()));

-- Storage: admin borra media del quiz
drop policy if exists "Admin delete quiz images" on storage.objects;
create policy "Admin delete quiz images"
  on storage.objects for delete
  using (
    bucket_id = 'quiz-images'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin delete quiz audio" on storage.objects;
create policy "Admin delete quiz audio"
  on storage.objects for delete
  using (
    bucket_id = 'quiz-audio'
    and public.is_admin_user(auth.uid())
  );

create or replace function public.quiz_delete_question_media(p_question_id uuid)
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
begin
  delete from storage.objects
  where bucket_id in ('quiz-images', 'quiz-audio')
    and (
      name like (p_question_id::text || '/%')
      or name = p_question_id::text
    );
end;
$$;

-- Borra una pregunta (no si está en vivo). Ranking mensual no se toca.
create or replace function public.quiz_delete_question(p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_q public.quiz_questions;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    return jsonb_build_object('deleted', false, 'reason', 'not_found');
  end if;

  if exists (
    select 1
    from public.quiz_rounds r
    where r.question_id = p_question_id
      and r.status = 'live'
  ) then
    raise exception 'No se puede borrar una pregunta en vivo. Cierra la ronda primero.';
  end if;

  -- Respuestas caen en cascada al borrar rondas.
  delete from public.quiz_rounds where question_id = p_question_id;
  perform public.quiz_delete_question_media(p_question_id);
  delete from public.quiz_questions where id = p_question_id;

  return jsonb_build_object('deleted', true, 'id', p_question_id);
end;
$$;

revoke all on function public.quiz_delete_question(uuid) from public;
grant execute on function public.quiz_delete_question(uuid) to authenticated;

revoke all on function public.quiz_delete_question_media(uuid) from public;
-- solo uso interno vía security definer

-- Borra preguntas creadas en un mes (Europe/Madrid). No toca ranking.
create or replace function public.quiz_delete_questions_for_month(p_year_month text)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_id uuid;
  v_deleted int := 0;
  v_skipped_live int := 0;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  if p_year_month is null or p_year_month !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'Mes inválido (YYYY-MM)';
  end if;

  for v_id in
    select q.id
    from public.quiz_questions q
    where to_char(timezone('Europe/Madrid', q.created_at), 'YYYY-MM') = p_year_month
  loop
    if exists (
      select 1 from public.quiz_rounds r
      where r.question_id = v_id and r.status = 'live'
    ) then
      v_skipped_live := v_skipped_live + 1;
      continue;
    end if;

    delete from public.quiz_rounds where question_id = v_id;
    perform public.quiz_delete_question_media(v_id);
    delete from public.quiz_questions where id = v_id;
    v_deleted := v_deleted + 1;
  end loop;

  return jsonb_build_object(
    'deleted', v_deleted,
    'skippedLive', v_skipped_live,
    'yearMonth', p_year_month
  );
end;
$$;

revoke all on function public.quiz_delete_questions_for_month(text) from public;
grant execute on function public.quiz_delete_questions_for_month(text) to authenticated;
