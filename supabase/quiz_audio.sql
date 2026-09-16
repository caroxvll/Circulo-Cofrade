-- Cofradero · audio opcional en preguntas del quiz
-- Ejecutar en SQL Editor después de quiz_daily.sql / quiz_fixes.sql

alter table public.quiz_questions
  add column if not exists audio_url text;

-- Payload en vivo: incluir audioUrl (sin spoiler)
create or replace function public.quiz_get_live_payload()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_answer public.quiz_answers;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round
  from public.quiz_rounds
  where status = 'live'
  order by launched_at desc
  limit 1;

  if v_round.id is null then
    return jsonb_build_object('state', 'idle');
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;
  select * into v_answer
  from public.quiz_answers
  where round_id = v_round.id and user_id = v_uid;

  return jsonb_build_object(
    'state', case when v_answer.answered_at is not null then 'answered' else 'live' end,
    'round', jsonb_build_object(
      'id', v_round.id,
      'launchedAt', v_round.launched_at,
      'closesAt', v_round.closes_at,
      'answerSeconds', v_round.answer_seconds
    ),
    'question', jsonb_build_object(
      'id', v_q.id,
      'prompt', v_q.prompt,
      'imageUrl', v_q.image_url,
      'audioUrl', v_q.audio_url,
      'optionA', v_q.option_a,
      'optionB', v_q.option_b,
      'optionC', v_q.option_c,
      'optionD', v_q.option_d,
      'explanation', case
        when v_answer.answered_at is not null then v_q.explanation
        else null
      end
    ),
    'answer', case
      when v_answer.id is null then null
      else jsonb_build_object(
        'openedAt', v_answer.opened_at,
        'answeredAt', v_answer.answered_at,
        'selectedOption', v_answer.selected_option,
        'isCorrect', v_answer.is_correct,
        'score', v_answer.score,
        'correctOption', case
          when v_answer.answered_at is not null then v_q.correct_option
          else null
        end
      )
    end
  );
end;
$$;

revoke all on function public.quiz_get_live_payload() from public;
grant execute on function public.quiz_get_live_payload() to authenticated;

-- Bucket público de audio (~1 MB, ~15–20 s)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quiz-audio',
  'quiz-audio',
  true,
  1048576,
  array[
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/wav',
    'audio/x-wav',
    'audio/x-m4a',
    'audio/m4a',
    'audio/mp3'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Quiz audio public read" on storage.objects;
create policy "Quiz audio public read"
  on storage.objects for select
  using (bucket_id = 'quiz-audio');

drop policy if exists "Quiz authors upload audio" on storage.objects;
create policy "Quiz authors upload audio"
  on storage.objects for insert
  with check (
    bucket_id = 'quiz-audio'
    and auth.uid() is not null
    and public.can_create_quiz_question(auth.uid())
  );

drop policy if exists "Quiz authors update audio" on storage.objects;
create policy "Quiz authors update audio"
  on storage.objects for update
  using (
    bucket_id = 'quiz-audio'
    and public.can_create_quiz_question(auth.uid())
  )
  with check (
    bucket_id = 'quiz-audio'
    and public.can_create_quiz_question(auth.uid())
  );
