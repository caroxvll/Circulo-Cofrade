-- Cofradero · la respuesta queda en blanco hasta las 00:00 (Madrid)
-- Ejecutar en el SQL Editor después de quiz_schedule_and_delete.sql.
-- Hasta que la ronda cierra no se dice si va bien, ni la opción correcta,
-- ni entran los puntos en el ranking (si no, el salto delata el acierto).

alter table public.quiz_answers
  add column if not exists forfeited boolean not null default false;

alter table public.quiz_answers
  add column if not exists timed_out boolean not null default false;

alter table public.quiz_answers
  add column if not exists scored_at timestamptz;

alter table public.quiz_answers
  add column if not exists reveal_seen_at timestamptz;

-- Lo ya puntuado en su día no se vuelve a sumar.
update public.quiz_answers
set scored_at = coalesce(answered_at, created_at)
where answered_at is not null
  and scored_at is null
  and is_correct is not null;

-- Suma puntos de una ronda ya cerrada. No la puede llamar el cliente.
create or replace function public.quiz_settle_round(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_answer public.quiz_answers;
  v_correct boolean;
  v_score int;
  v_elapsed_entry numeric;
  v_elapsed_answer numeric;
  v_remaining numeric;
  v_entry_bonus numeric;
  v_timer_bonus numeric;
  v_month text;
begin
  perform set_config('quiz.staff_write', '1', true);

  select * into v_round from public.quiz_rounds where id = p_round_id;
  if v_round.id is null then
    return;
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;
  if v_q.id is null then
    return;
  end if;

  v_month := to_char(
    timezone('Europe/Madrid', coalesce(v_round.launched_at, now())),
    'YYYY-MM'
  );

  for v_answer in
    select *
    from public.quiz_answers
    where round_id = p_round_id
      and answered_at is not null
      and scored_at is null
    for update
  loop
    v_elapsed_answer := extract(epoch from (v_answer.answered_at - v_answer.opened_at));
    if v_answer.forfeited
       or v_answer.timed_out
       or v_elapsed_answer > v_round.answer_seconds + 1.5 then
      v_correct := false;
      v_score := -40;
    else
      v_correct := v_answer.selected_option = v_q.correct_option;
      if v_correct then
        v_elapsed_entry := extract(epoch from (v_answer.opened_at - v_round.launched_at));
        if v_elapsed_entry < 0 then
          v_elapsed_entry := 0;
        end if;
        v_entry_bonus := greatest(0, 50 * (1 - least(v_elapsed_entry, 1800) / 1800.0));
        v_remaining := greatest(0, v_round.answer_seconds - v_elapsed_answer);
        v_timer_bonus := (v_remaining / v_round.answer_seconds::numeric) * 50;
        v_score := round(100 + v_entry_bonus + v_timer_bonus)::int;
      else
        v_score := -40;
      end if;
    end if;

    update public.quiz_answers
    set
      is_correct = v_correct,
      score = v_score,
      scored_at = now()
    where id = v_answer.id;

    insert into public.quiz_monthly_scores as s (
      user_id, year_month, points, answers_count, correct_count, updated_at
    ) values (
      v_answer.user_id,
      v_month,
      v_score,
      1,
      case when v_correct then 1 else 0 end,
      now()
    )
    on conflict (user_id, year_month) do update set
      points = s.points + excluded.points,
      answers_count = s.answers_count + 1,
      correct_count = s.correct_count + excluded.correct_count,
      updated_at = now();
  end loop;
end;
$$;

revoke all on function public.quiz_settle_round(uuid) from public;
revoke all on function public.quiz_settle_round(uuid) from anon;
revoke all on function public.quiz_settle_round(uuid) from authenticated;

-- Al pasar la ronda a cerrada (medianoche o cierre manual) se puntúa.
create or replace function public.quiz_rounds_before_close()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'closed'
     and old.status is distinct from 'closed' then
    perform public.quiz_settle_round(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists quiz_rounds_settle_before_close on public.quiz_rounds;
create trigger quiz_rounds_settle_before_close
  before update on public.quiz_rounds
  for each row
  execute function public.quiz_rounds_before_close();

-- Nadie reescribe la opción después de contestar, ni lee el acierto antes de tiempo
-- cambiando la fila. El cierre y el "ya lo vi" pasan con quiz.staff_write.
create or replace function public.quiz_answers_lock_after_send()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.answered_at is not null
     and coalesce(current_setting('quiz.staff_write', true), '') <> '1' then
    if new.selected_option is distinct from old.selected_option
       or new.answered_at is distinct from old.answered_at
       or new.forfeited is distinct from old.forfeited
       or new.timed_out is distinct from old.timed_out
       or new.is_correct is distinct from old.is_correct
       or new.score is distinct from old.score
       or new.scored_at is distinct from old.scored_at
       or new.opened_at is distinct from old.opened_at
       or new.reveal_seen_at is distinct from old.reveal_seen_at
       or new.user_id is distinct from old.user_id
       or new.round_id is distinct from old.round_id then
      raise exception 'La respuesta ya está cerrada';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists quiz_answers_lock_after_send on public.quiz_answers;
create trigger quiz_answers_lock_after_send
  before update on public.quiz_answers
  for each row
  execute function public.quiz_answers_lock_after_send();

create or replace function public.quiz_submit_answer(
  p_round_id uuid,
  p_option text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
  v_elapsed_answer numeric;
  v_timed_out boolean;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if p_option is null or p_option not in ('a', 'b', 'c', 'd') then
    raise exception 'Opción inválida';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round from public.quiz_rounds where id = p_round_id for update;
  if v_round.id is null or v_round.status <> 'live' then
    raise exception 'La pregunta no está disponible';
  end if;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid
  for update;

  if v_answer.id is null then
    insert into public.quiz_answers (round_id, user_id, opened_at)
    values (p_round_id, v_uid, now())
    returning * into v_answer;
  end if;

  if v_answer.answered_at is not null then
    if v_answer.scored_at is null then
      return jsonb_build_object(
        'sealed', true,
        'selectedOption', v_answer.selected_option,
        'forfeited', v_answer.forfeited,
        'timedOut', v_answer.timed_out
      );
    end if;
    return jsonb_build_object(
      'sealed', false,
      'isCorrect', v_answer.is_correct,
      'score', v_answer.score,
      'correctOption', (
        select correct_option from public.quiz_questions where id = v_round.question_id
      ),
      'explanation', (
        select explanation from public.quiz_questions where id = v_round.question_id
      ),
      'selectedOption', v_answer.selected_option,
      'forfeited', v_answer.forfeited,
      'timedOut', v_answer.timed_out
    );
  end if;

  v_elapsed_answer := extract(epoch from (now() - v_answer.opened_at));
  v_timed_out := v_elapsed_answer > v_round.answer_seconds + 1.5;

  perform set_config('quiz.staff_write', '1', true);
  update public.quiz_answers
  set
    selected_option = case when v_timed_out then null else p_option end,
    forfeited = false,
    timed_out = v_timed_out,
    answered_at = now(),
    is_correct = null,
    score = 0,
    scored_at = null
  where id = v_answer.id
  returning * into v_answer;

  return jsonb_build_object(
    'sealed', true,
    'selectedOption', v_answer.selected_option,
    'forfeited', false,
    'timedOut', v_timed_out
  );
end;
$$;

revoke all on function public.quiz_submit_answer(uuid, text) from public;
grant execute on function public.quiz_submit_answer(uuid, text) to authenticated;

create or replace function public.quiz_forfeit_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round from public.quiz_rounds where id = p_round_id for update;
  if v_round.id is null then
    raise exception 'Ronda no encontrada';
  end if;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid
  for update;

  if v_answer.id is null then
    return jsonb_build_object(
      'forfeited', false,
      'reason', 'not_opened'
    );
  end if;

  if v_answer.answered_at is not null then
    return jsonb_build_object(
      'sealed', v_answer.scored_at is null,
      'forfeited', v_answer.forfeited,
      'timedOut', v_answer.timed_out,
      'selectedOption', v_answer.selected_option,
      'isCorrect', case when v_answer.scored_at is null then null else v_answer.is_correct end,
      'score', case when v_answer.scored_at is null then null else v_answer.score end
    );
  end if;

  perform set_config('quiz.staff_write', '1', true);
  update public.quiz_answers
  set
    selected_option = null,
    forfeited = true,
    timed_out = false,
    is_correct = null,
    answered_at = now(),
    score = 0,
    scored_at = null
  where id = v_answer.id;

  return jsonb_build_object(
    'sealed', true,
    'forfeited', true,
    'timedOut', false
  );
end;
$$;

revoke all on function public.quiz_forfeit_round(uuid) from public;
grant execute on function public.quiz_forfeit_round(uuid) to authenticated;

create or replace function public.quiz_mark_reveal_seen(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  perform set_config('quiz.staff_write', '1', true);
  update public.quiz_answers
  set reveal_seen_at = now()
  where round_id = p_round_id
    and user_id = v_uid
    and answered_at is not null
    and reveal_seen_at is null;
end;
$$;

revoke all on function public.quiz_mark_reveal_seen(uuid) from public;
grant execute on function public.quiz_mark_reveal_seen(uuid) to authenticated;

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
  v_reveal public.quiz_rounds;
  v_reveal_q public.quiz_questions;
  v_reveal_a public.quiz_answers;
  v_answered int;
  v_correct int;
  v_players jsonb;
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

  if v_round.id is not null then
    select * into v_q from public.quiz_questions where id = v_round.question_id;
    select * into v_answer
    from public.quiz_answers
    where round_id = v_round.id and user_id = v_uid;
  end if;

  select r.* into v_reveal
  from public.quiz_rounds r
  join public.quiz_answers a
    on a.round_id = r.id and a.user_id = v_uid
  where r.status = 'closed'
    and a.answered_at is not null
    and a.scored_at is not null
    and a.reveal_seen_at is null
    and r.closes_at is not null
    and r.closes_at <= now()
    and r.closes_at > now() - interval '36 hours'
  order by r.closes_at desc
  limit 1;

  if v_reveal.id is not null then
    select * into v_reveal_q from public.quiz_questions where id = v_reveal.question_id;
    select * into v_reveal_a
    from public.quiz_answers
    where round_id = v_reveal.id and user_id = v_uid;

    select
      count(*) filter (where answered_at is not null),
      count(*) filter (where is_correct)
    into v_answered, v_correct
    from public.quiz_answers
    where round_id = v_reveal.id;

    select coalesce(jsonb_agg(
      jsonb_build_object(
        'name', coalesce(nullif(btrim(p.display_name), ''), '@' || p.handle),
        'correct', a.is_correct
      )
      order by a.answered_at
    ), '[]'::jsonb)
    into v_players
    from (
      select *
      from public.quiz_answers
      where round_id = v_reveal.id
        and answered_at is not null
      order by answered_at
      limit 40
    ) a
    join public.profiles p on p.id = a.user_id;
  end if;

  return jsonb_build_object(
    'state', case
      when v_round.id is null then 'idle'
      when v_answer.answered_at is not null then 'answered'
      else 'live'
    end,
    'round', case
      when v_round.id is null then null
      else jsonb_build_object(
        'id', v_round.id,
        'launchedAt', v_round.launched_at,
        'closesAt', v_round.closes_at,
        'answerSeconds', v_round.answer_seconds
      )
    end,
    'question', case
      when v_round.id is null then null
      else jsonb_build_object(
        'id', v_q.id,
        'prompt', v_q.prompt,
        'imageUrl', v_q.image_url,
        'audioUrl', v_q.audio_url,
        'optionA', v_q.option_a,
        'optionB', v_q.option_b,
        'optionC', v_q.option_c,
        'optionD', v_q.option_d,
        'explanation', null
      )
    end,
    'answer', case
      when v_answer.id is null then null
      else jsonb_build_object(
        'openedAt', v_answer.opened_at,
        'answeredAt', v_answer.answered_at,
        'selectedOption', v_answer.selected_option,
        'forfeited', v_answer.forfeited,
        'timedOut', v_answer.timed_out,
        'isCorrect', null,
        'score', null,
        'correctOption', null
      )
    end,
    'reveal', case
      when v_reveal.id is null then null
      else jsonb_build_object(
        'roundId', v_reveal.id,
        'prompt', v_reveal_q.prompt,
        'imageUrl', v_reveal_q.image_url,
        'optionA', v_reveal_q.option_a,
        'optionB', v_reveal_q.option_b,
        'optionC', v_reveal_q.option_c,
        'optionD', v_reveal_q.option_d,
        'explanation', v_reveal_q.explanation,
        'selectedOption', v_reveal_a.selected_option,
        'correctOption', v_reveal_q.correct_option,
        'isCorrect', v_reveal_a.is_correct,
        'score', v_reveal_a.score,
        'forfeited', v_reveal_a.forfeited,
        'timedOut', v_reveal_a.timed_out,
        'answeredCount', v_answered,
        'correctCount', v_correct,
        'players', v_players
      )
    end
  );
end;
$$;

revoke all on function public.quiz_get_live_payload() from public;
grant execute on function public.quiz_get_live_payload() to authenticated;
