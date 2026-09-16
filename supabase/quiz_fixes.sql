-- Cofradero · cerrar ronda en vivo (admin) + políticas storage quiz-images
-- Ejecutar después de quiz_daily.sql
--
-- Si la app dice «Ya hay una pregunta en curso» y el cronómetro va a 0 s,
-- desatasca YA con:
--   update public.quiz_rounds set status = 'closed' where status = 'live';

create or replace function public.quiz_close_live_round()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede cerrar la ronda';
  end if;

  update public.quiz_rounds
  set status = 'closed'
  where status = 'live';

  get diagnostics v_n = row_count;

  return jsonb_build_object('closed', v_n);
end;
$$;

revoke all on function public.quiz_close_live_round() from public;
grant execute on function public.quiz_close_live_round() to authenticated;

-- Lanzar: si p_force, cierra la live anterior
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

revoke all on function public.quiz_launch_round(uuid, boolean) from public;
grant execute on function public.quiz_launch_round(uuid, boolean) to authenticated;

-- Mantener overload de 1 arg (compat)
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

-- Bucket público de imágenes (idempotente vía API Dashboard si falla)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quiz-images',
  'quiz-images',
  true,
  524288,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Quiz images public read" on storage.objects;
create policy "Quiz images public read"
  on storage.objects for select
  using (bucket_id = 'quiz-images');

drop policy if exists "Quiz authors upload images" on storage.objects;
create policy "Quiz authors upload images"
  on storage.objects for insert
  with check (
    bucket_id = 'quiz-images'
    and auth.uid() is not null
    and public.can_create_quiz_question(auth.uid())
  );

drop policy if exists "Quiz authors update images" on storage.objects;
create policy "Quiz authors update images"
  on storage.objects for update
  using (
    bucket_id = 'quiz-images'
    and public.can_create_quiz_question(auth.uid())
  )
  with check (
    bucket_id = 'quiz-images'
    and public.can_create_quiz_question(auth.uid())
  );
