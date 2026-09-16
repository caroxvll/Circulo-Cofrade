-- Cofradero · ronda en vivo hasta medianoche del día actual (Europe/Madrid)
-- Ejecutar en SQL Editor después de quiz_daily.sql / quiz_fixes.sql
--
-- No son 24 h desde el lanzamiento: cierra a las 00:00 (inicio del día siguiente).

alter table public.quiz_rounds
  drop constraint if exists quiz_rounds_open_minutes_check;

alter table public.quiz_rounds
  alter column open_minutes set default 1440;

alter table public.quiz_rounds
  add constraint quiz_rounds_open_minutes_check
  check (open_minutes between 1 and 2880);

-- Ronda live actual: cierra a medianoche de hoy (Madrid)
update public.quiz_rounds
set
  closes_at = (
    (timezone('Europe/Madrid', now())::date + 1)::timestamp
  ) at time zone 'Europe/Madrid',
  open_minutes = greatest(
    1,
    ceil(
      extract(
        epoch from (
          ((timezone('Europe/Madrid', now())::date + 1)::timestamp
            at time zone 'Europe/Madrid')
          - coalesce(launched_at, now())
        )
      ) / 60.0
    )::int
  )
where status = 'live';

-- Lanzar: abierta hasta fin del día (Madrid); si p_force, cierra la live anterior
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

  -- 00:00 del día siguiente en Europe/Madrid = fin del día actual
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

revoke all on function public.quiz_launch_round(uuid, boolean) from public;
grant execute on function public.quiz_launch_round(uuid, boolean) to authenticated;

create or replace function public.quiz_launch_round(p_question_id uuid)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.quiz_launch_round(p_question_id, false);
end;
$$;

revoke all on function public.quiz_launch_round(uuid) from public;
grant execute on function public.quiz_launch_round(uuid) to authenticated;
