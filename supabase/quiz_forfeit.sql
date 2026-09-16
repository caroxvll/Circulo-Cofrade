-- Cofradero · abandonar pregunta = fallo (si sales tras Empezar)
-- Ejecutar en SQL Editor después de quiz_daily.sql

create or replace function public.quiz_forfeit_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
  v_month text;
  v_score int := -40;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round from public.quiz_rounds where id = p_round_id for update;
  if v_round.id is null then
    raise exception 'Ronda no encontrada';
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid
  for update;

  -- Sin haber empezado: no hay nada que abandonar.
  if v_answer.id is null then
    return jsonb_build_object(
      'forfeited', false,
      'reason', 'not_opened'
    );
  end if;

  -- Ya respondió: idempotente.
  if v_answer.answered_at is not null then
    return jsonb_build_object(
      'forfeited', false,
      'reason', 'already_answered',
      'isCorrect', v_answer.is_correct,
      'score', v_answer.score,
      'correctOption', v_q.correct_option,
      'selectedOption', v_answer.selected_option,
      'explanation', v_q.explanation
    );
  end if;

  update public.quiz_answers
  set
    -- Opción distinta de la correcta (abandono; no cuenta como acierto).
    selected_option = case
      when v_q.correct_option = 'a' then 'b'
      else 'a'
    end,
    is_correct = false,
    answered_at = now(),
    score = v_score
  where id = v_answer.id
  returning * into v_answer;

  v_month := to_char(timezone('Europe/Madrid', now()), 'YYYY-MM');

  insert into public.quiz_monthly_scores as s (
    user_id, year_month, points, answers_count, correct_count, updated_at
  ) values (
    v_uid,
    v_month,
    v_score,
    1,
    0,
    now()
  )
  on conflict (user_id, year_month) do update set
    points = s.points + excluded.points,
    answers_count = s.answers_count + 1,
    updated_at = now();

  return jsonb_build_object(
    'forfeited', true,
    'isCorrect', false,
    'score', v_score,
    'correctOption', v_q.correct_option,
    'selectedOption', v_answer.selected_option,
    'explanation', v_q.explanation
  );
end;
$$;

revoke all on function public.quiz_forfeit_round(uuid) from public;
grant execute on function public.quiz_forfeit_round(uuid) to authenticated;
