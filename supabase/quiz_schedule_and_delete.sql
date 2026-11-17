-- Cofradero · borrar preguntas sin tocar storage.objects
-- y programar una pregunta por día (Europe/Madrid).
-- Ejecutar en el SQL Editor después de quiz_day_long_rounds.sql.

-- Supabase bloquea DELETE directo en storage.objects (código 42501).
-- La media se borra desde la app y la web con la Storage API.
create or replace function public.quiz_delete_question_media(p_question_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  return;
end;
$$;

create or replace function public.quiz_delete_question(p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
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

  delete from public.quiz_rounds where question_id = p_question_id;
  delete from public.quiz_questions where id = p_question_id;

  return jsonb_build_object('deleted', true, 'id', p_question_id);
end;
$$;

create or replace function public.quiz_delete_questions_for_month(p_year_month text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_deleted int := 0;
  v_skipped_live int := 0;
  v_ids jsonb := '[]'::jsonb;
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
    delete from public.quiz_questions where id = v_id;
    v_deleted := v_deleted + 1;
    v_ids := v_ids || to_jsonb(v_id);
  end loop;

  return jsonb_build_object(
    'deleted', v_deleted,
    'skippedLive', v_skipped_live,
    'yearMonth', p_year_month,
    'ids', v_ids
  );
end;
$$;

alter table public.quiz_rounds
  add column if not exists play_on date;

create unique index if not exists quiz_rounds_one_play_on_idx
  on public.quiz_rounds (play_on)
  where status in ('scheduled', 'live') and play_on is not null;

-- Cierra lo caducado y, si no hay ronda en vivo, abre la programada de hoy.
create or replace function public.quiz_close_expired_rounds()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  update public.quiz_rounds
  set status = 'closed'
  where status = 'live'
    and closes_at is not null
    and closes_at <= now();

  update public.quiz_rounds
  set status = 'closed'
  where status = 'scheduled'
    and closes_at is not null
    and closes_at <= now();

  if exists (select 1 from public.quiz_rounds where status = 'live') then
    return;
  end if;

  select id into v_id
  from public.quiz_rounds
  where status = 'scheduled'
    and launched_at <= now()
    and (closes_at is null or closes_at > now())
  order by launched_at
  limit 1;

  if v_id is not null then
    update public.quiz_rounds
    set status = 'live'
    where id = v_id
      and status = 'scheduled';
  end if;
end;
$$;

create or replace function public.quiz_launch_round(
  p_question_id uuid,
  p_force boolean default false
)
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
  v_day date;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede lanzar la pregunta';
  end if;

  perform public.quiz_close_expired_rounds();

  if exists (select 1 from public.quiz_rounds where status = 'live') then
    if coalesce(p_force, false) then
      update public.quiz_rounds set status = 'closed' where status = 'live';
    else
      raise exception 'Ya hay una pregunta en curso';
    end if;
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    raise exception 'Pregunta no encontrada';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'La pregunta debe estar aprobada';
  end if;

  delete from public.quiz_rounds
  where question_id = p_question_id
    and status = 'scheduled';

  v_day := timezone('Europe/Madrid', now())::date;
  v_closes := ((v_day + 1)::timestamp) at time zone 'Europe/Madrid';
  v_open := greatest(
    1,
    ceil(extract(epoch from (v_closes - now())) / 60.0)::int
  );

  insert into public.quiz_rounds (
    question_id, status, launched_at, closes_at, answer_seconds,
    open_minutes, created_by, play_on
  ) values (
    p_question_id, 'live', now(), v_closes, 15, v_open, auth.uid(), v_day
  )
  returning * into v_round;

  return v_round;
end;
$$;

create or replace function public.quiz_schedule_round(
  p_question_id uuid,
  p_day date
)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := timezone('Europe/Madrid', now())::date;
  v_q public.quiz_questions;
  v_round public.quiz_rounds;
  v_start timestamptz;
  v_closes timestamptz;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede programar la pregunta';
  end if;

  if p_day is null or p_day < v_today then
    raise exception 'Elige hoy o un día futuro';
  end if;

  if p_day = v_today then
    return public.quiz_launch_round(p_question_id, false);
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    raise exception 'Pregunta no encontrada';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'La pregunta debe estar aprobada';
  end if;

  if exists (
    select 1 from public.quiz_rounds
    where question_id = p_question_id
      and status in ('scheduled', 'live')
  ) then
    raise exception 'Esa pregunta ya está programada o en vivo';
  end if;

  if exists (
    select 1 from public.quiz_rounds
    where play_on = p_day
      and status in ('scheduled', 'live')
  ) then
    raise exception 'Ese día ya tiene una pregunta';
  end if;

  v_start := (p_day::timestamp) at time zone 'Europe/Madrid';
  v_closes := ((p_day + 1)::timestamp) at time zone 'Europe/Madrid';

  insert into public.quiz_rounds (
    question_id, status, launched_at, closes_at, answer_seconds,
    open_minutes, created_by, play_on
  ) values (
    p_question_id,
    'scheduled',
    v_start,
    v_closes,
    15,
    greatest(1, ceil(extract(epoch from (v_closes - v_start)) / 60.0)::int),
    auth.uid(),
    p_day
  )
  returning * into v_round;

  return v_round;
end;
$$;

create or replace function public.quiz_cancel_scheduled_round(p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  delete from public.quiz_rounds
  where question_id = p_question_id
    and status = 'scheduled';
  get diagnostics v_n = row_count;

  return jsonb_build_object('cancelled', v_n > 0);
end;
$$;

revoke all on function public.quiz_schedule_round(uuid, date) from public;
grant execute on function public.quiz_schedule_round(uuid, date) to authenticated;

revoke all on function public.quiz_cancel_scheduled_round(uuid) from public;
grant execute on function public.quiz_cancel_scheduled_round(uuid) to authenticated;
