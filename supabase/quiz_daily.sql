-- Cofradero · Pregunta en vivo (quiz)
-- Ejecutar después de roles_v2.sql y notification_social.sql / calendar_notify.sql
-- Idempotente.

-- Preferencia de avisos
alter table public.notification_preferences
  add column if not exists notify_quiz boolean not null default true;

create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'calendar' then coalesce(
      (select notify_calendar from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'quiz' then coalesce(
      (select notify_quiz from public.notification_preferences where user_id = p_user_id),
      true
    )
    else true
  end;
$$;

-- Preguntas propuestas / aprobadas
create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  prompt text not null check (char_length(btrim(prompt)) between 3 and 280),
  image_url text,
  option_a text not null check (char_length(btrim(option_a)) between 1 and 120),
  option_b text not null check (char_length(btrim(option_b)) between 1 and 120),
  option_c text not null check (char_length(btrim(option_c)) between 1 and 120),
  option_d text not null check (char_length(btrim(option_d)) between 1 and 120),
  correct_option text not null check (correct_option in ('a', 'b', 'c', 'd')),
  explanation text check (
    explanation is null or char_length(btrim(explanation)) between 3 and 280
  ),
  status text not null default 'pending_review'
    check (status in ('draft', 'pending_review', 'approved', 'rejected')),
  created_by uuid references public.profiles (id) on delete set null,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists quiz_questions_status_idx
  on public.quiz_questions (status, created_at desc);

-- Rondas en vivo
create table if not exists public.quiz_rounds (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.quiz_questions (id) on delete restrict,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'closed')),
  launched_at timestamptz,
  closes_at timestamptz,
  answer_seconds int not null default 15 check (answer_seconds between 5 and 60),
  open_minutes int not null default 1440 check (open_minutes between 1 and 2880),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists quiz_rounds_status_idx
  on public.quiz_rounds (status, launched_at desc);

-- Una sola ronda live a la vez (parcial)
create unique index if not exists quiz_rounds_one_live_idx
  on public.quiz_rounds (status)
  where status = 'live';

-- Respuestas de usuarios
create table if not exists public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.quiz_rounds (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  selected_option text check (
    selected_option is null or selected_option in ('a', 'b', 'c', 'd')
  ),
  is_correct boolean,
  opened_at timestamptz not null default now(),
  answered_at timestamptz,
  score int not null default 0,
  created_at timestamptz not null default now(),
  unique (round_id, user_id)
);

create index if not exists quiz_answers_user_idx
  on public.quiz_answers (user_id, created_at desc);

create index if not exists quiz_answers_round_score_idx
  on public.quiz_answers (round_id, score desc);

-- Ranking mensual acumulado
create table if not exists public.quiz_monthly_scores (
  user_id uuid not null references public.profiles (id) on delete cascade,
  year_month text not null check (year_month ~ '^[0-9]{4}-[0-9]{2}$'),
  points int not null default 0,
  answers_count int not null default 0,
  correct_count int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, year_month)
);

create index if not exists quiz_monthly_scores_rank_idx
  on public.quiz_monthly_scores (year_month, points desc);

alter table public.quiz_questions enable row level security;
alter table public.quiz_rounds enable row level security;
alter table public.quiz_answers enable row level security;
alter table public.quiz_monthly_scores enable row level security;

-- Junta ve / gestiona preguntas
drop policy if exists "Junta lee preguntas quiz" on public.quiz_questions;
create policy "Junta lee preguntas quiz"
  on public.quiz_questions for select
  using (public.is_junta_member(auth.uid()));

drop policy if exists "Junta crea preguntas quiz" on public.quiz_questions;
create policy "Junta crea preguntas quiz"
  on public.quiz_questions for insert
  with check (
    public.is_junta_member(auth.uid())
    and created_by = auth.uid()
  );

drop policy if exists "Admin actualiza preguntas quiz" on public.quiz_questions;
create policy "Admin actualiza preguntas quiz"
  on public.quiz_questions for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Creador edita pregunta pendiente quiz" on public.quiz_questions;
create policy "Creador edita pregunta pendiente quiz"
  on public.quiz_questions for update
  using (
    created_by = auth.uid()
    and status = 'pending_review'
  )
  with check (
    created_by = auth.uid()
    and status = 'pending_review'
  );

-- Rondas: junta lee; admin escribe; público autenticado lee live/closed (sin join a correct)
drop policy if exists "Usuarios leen rondas quiz" on public.quiz_rounds;
create policy "Usuarios leen rondas quiz"
  on public.quiz_rounds for select
  using (
    status in ('live', 'closed')
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Admin gestiona rondas quiz" on public.quiz_rounds;
create policy "Admin gestiona rondas quiz"
  on public.quiz_rounds for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Respuestas: cada uno las suyas; junta puede leer
drop policy if exists "Usuario gestiona su respuesta quiz" on public.quiz_answers;
create policy "Usuario gestiona su respuesta quiz"
  on public.quiz_answers for select
  using (
    user_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Usuario inserta su respuesta quiz" on public.quiz_answers;
create policy "Usuario inserta su respuesta quiz"
  on public.quiz_answers for insert
  with check (user_id = auth.uid());

drop policy if exists "Usuario actualiza su respuesta quiz" on public.quiz_answers;
create policy "Usuario actualiza su respuesta quiz"
  on public.quiz_answers for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Ranking mensual: lectura pública autenticada
drop policy if exists "Usuarios leen ranking quiz" on public.quiz_monthly_scores;
create policy "Usuarios leen ranking quiz"
  on public.quiz_monthly_scores for select
  using (auth.uid() is not null);

-- Storage bucket (crear en Dashboard si no existe): quiz-images, public read

-- Cierra rondas caducadas
create or replace function public.quiz_close_expired_rounds()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.quiz_rounds
  set status = 'closed'
  where status = 'live'
    and closes_at is not null
    and closes_at <= now();
end;
$$;

-- Lanzar ronda desde pregunta aprobada
create or replace function public.quiz_launch_round(p_question_id uuid)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q public.quiz_questions;
  v_round public.quiz_rounds;
  v_closes timestamptz;
  v_open int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede lanzar la pregunta';
  end if;

  perform public.quiz_close_expired_rounds();

  if exists (select 1 from public.quiz_rounds where status = 'live') then
    raise exception 'Ya hay una pregunta en curso';
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    raise exception 'Pregunta no encontrada';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'La pregunta debe estar aprobada';
  end if;

  -- Fin del día actual (Europe/Madrid)
  v_closes := (
    (timezone('Europe/Madrid', now())::date + 1)::timestamp
  ) at time zone 'Europe/Madrid';

  v_open := greatest(
    1,
    ceil(extract(epoch from (v_closes - now())) / 60.0)::int
  );

  insert into public.quiz_rounds (
    question_id, status, launched_at, closes_at, answer_seconds, open_minutes, created_by
  ) values (
    p_question_id, 'live', now(), v_closes, 15, v_open, auth.uid()
  )
  returning * into v_round;

  return v_round;
end;
$$;

revoke all on function public.quiz_launch_round(uuid) from public;
grant execute on function public.quiz_launch_round(uuid) to authenticated;

-- Payload de juego sin spoiler de respuesta
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

-- Abrir cronómetro personal
create or replace function public.quiz_open_round(p_round_id uuid)
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

  select * into v_round from public.quiz_rounds where id = p_round_id;
  if v_round.id is null or v_round.status <> 'live' then
    raise exception 'La pregunta no está disponible';
  end if;
  if v_round.closes_at is not null and v_round.closes_at <= now() then
    raise exception 'La ronda ha cerrado';
  end if;

  insert into public.quiz_answers (round_id, user_id, opened_at)
  values (p_round_id, v_uid, now())
  on conflict (round_id, user_id) do nothing;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid;

  if v_answer.answered_at is not null then
    raise exception 'Ya has respondido esta pregunta';
  end if;

  return jsonb_build_object(
    'openedAt', v_answer.opened_at,
    'answerSeconds', v_round.answer_seconds,
    'serverNow', now()
  );
end;
$$;

revoke all on function public.quiz_open_round(uuid) from public;
grant execute on function public.quiz_open_round(uuid) to authenticated;

-- Enviar respuesta + score
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
  v_q public.quiz_questions;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
  v_correct boolean;
  v_score int;
  v_entry_bonus numeric;
  v_timer_bonus numeric;
  v_elapsed_entry numeric;
  v_elapsed_answer numeric;
  v_remaining numeric;
  v_month text;
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

  select * into v_q from public.quiz_questions where id = v_round.question_id;

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
    raise exception 'Ya has respondido esta pregunta';
  end if;

  v_elapsed_entry := extract(epoch from (v_answer.opened_at - v_round.launched_at));
  if v_elapsed_entry < 0 then
    v_elapsed_entry := 0;
  end if;
  -- Bonus llegada: 50 → 0 en 30 minutos
  v_entry_bonus := greatest(0, 50 * (1 - least(v_elapsed_entry, 1800) / 1800.0));

  v_elapsed_answer := extract(epoch from (now() - v_answer.opened_at));
  v_remaining := greatest(0, v_round.answer_seconds - v_elapsed_answer);
  v_timer_bonus := (v_remaining / v_round.answer_seconds::numeric) * 50;

  v_correct := (p_option = v_q.correct_option);

  if v_elapsed_answer > v_round.answer_seconds + 1.5 then
    -- Timeout: cuenta como fallo
    v_correct := false;
    v_score := -40;
  elsif v_correct then
    v_score := round(100 + v_entry_bonus + v_timer_bonus)::int;
  else
    v_score := -40;
  end if;

  update public.quiz_answers
  set
    selected_option = p_option,
    is_correct = v_correct,
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
    case when v_correct then 1 else 0 end,
    now()
  )
  on conflict (user_id, year_month) do update set
    points = s.points + excluded.points,
    answers_count = s.answers_count + 1,
    correct_count = s.correct_count + excluded.correct_count,
    updated_at = now();

  return jsonb_build_object(
    'isCorrect', v_correct,
    'score', v_score,
    'correctOption', v_q.correct_option,
    'explanation', v_q.explanation,
    'selectedOption', p_option
  );
end;
$$;

revoke all on function public.quiz_submit_answer(uuid, text) from public;
grant execute on function public.quiz_submit_answer(uuid, text) to authenticated;

-- Ranking del mes
create or replace function public.quiz_monthly_leaderboard(p_year_month text default null)
returns table (
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  points int,
  answers_count int,
  correct_count int,
  rank bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month text := coalesce(
    p_year_month,
    to_char(timezone('Europe/Madrid', now()), 'YYYY-MM')
  );
begin
  return query
  select
    s.user_id,
    p.handle,
    p.display_name,
    p.avatar_url,
    s.points,
    s.answers_count,
    s.correct_count,
    rank() over (order by s.points desc, s.correct_count desc, s.updated_at asc)
  from public.quiz_monthly_scores s
  join public.profiles p on p.id = s.user_id
  where s.year_month = v_month
    and p.suspended_at is null
  order by s.points desc, s.correct_count desc, s.updated_at asc
  limit 100;
end;
$$;

revoke all on function public.quiz_monthly_leaderboard(text) from public;
grant execute on function public.quiz_monthly_leaderboard(text) to authenticated;

-- Notificar al lanzar
create or replace function public.notify_users_on_quiz_live()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prompt text;
begin
  if new.status <> 'live' then
    return new;
  end if;
  if tg_op = 'UPDATE' and coalesce(old.status, '') = 'live' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select left(prompt, 80) into v_prompt
  from public.quiz_questions
  where id = new.question_id;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    p.id,
    'quiz',
    '¡Pregunta en vivo!',
    coalesce(v_prompt, 'Tienes 15 segundos para responder'),
    jsonb_build_object(
      'route', '/quiz',
      'roundId', new.id::text
    )
  from public.profiles p
  where p.suspended_at is null
    and public.notify_pref_enabled(p.id, 'quiz');

  return new;
end;
$$;

drop trigger if exists on_quiz_round_live_notify on public.quiz_rounds;
create trigger on_quiz_round_live_notify
  after insert or update of status on public.quiz_rounds
  for each row execute function public.notify_users_on_quiz_live();
