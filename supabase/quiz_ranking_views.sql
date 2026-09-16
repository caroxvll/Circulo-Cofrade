-- Cofradero · ranking mensual escalable (cerca de mí / top / por encima / abajo)
-- Ejecutar en SQL Editor después de quiz_daily.sql

create or replace function public.quiz_monthly_ranking_bundle(
  p_year_month text default null,
  p_mode text default 'around',
  p_limit int default 40
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month text := coalesce(
    p_year_month,
    to_char(timezone('Europe/Madrid', now()), 'YYYY-MM')
  );
  v_mode text := lower(coalesce(nullif(btrim(p_mode), ''), 'around'));
  v_limit int := least(greatest(coalesce(p_limit, 40), 5), 100);
  v_uid uuid := auth.uid();
  v_half int;
  v_my_rank bigint;
  v_total int;
  v_me jsonb;
  v_entries jsonb;
  v_lo bigint;
  v_hi bigint;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if v_mode not in ('top', 'around', 'above', 'below') then
    v_mode := 'around';
  end if;

  v_half := greatest(v_limit / 2, 5);

  select count(*)::int into v_total
  from public.quiz_monthly_scores s
  join public.profiles p on p.id = s.user_id
  where s.year_month = v_month
    and p.suspended_at is null;

  with ranked as (
    select
      s.user_id,
      p.handle,
      p.display_name,
      p.avatar_url,
      s.points,
      s.answers_count,
      s.correct_count,
      rank() over (
        order by s.points desc, s.correct_count desc, s.updated_at asc
      ) as rnk
    from public.quiz_monthly_scores s
    join public.profiles p on p.id = s.user_id
    where s.year_month = v_month
      and p.suspended_at is null
  )
  select
    jsonb_build_object(
      'userId', r.user_id,
      'handle', r.handle,
      'displayName', r.display_name,
      'avatarUrl', r.avatar_url,
      'points', r.points,
      'answersCount', r.answers_count,
      'correctCount', r.correct_count,
      'rank', r.rnk
    ),
    r.rnk
  into v_me, v_my_rank
  from ranked r
  where r.user_id = v_uid;

  if v_mode = 'around' and v_my_rank is null then
    v_mode := 'top';
  end if;

  if v_mode = 'top' then
    v_lo := 1;
    v_hi := v_limit;
  elsif v_mode = 'around' then
    v_lo := greatest(1, v_my_rank - v_half);
    v_hi := v_my_rank + v_half;
  elsif v_mode = 'above' then
    if v_my_rank is null or v_my_rank <= 1 then
      v_lo := 1;
      v_hi := 0; -- vacío
    else
      v_lo := greatest(1, v_my_rank - v_limit);
      v_hi := v_my_rank - 1;
    end if;
  else -- below
    if v_my_rank is null then
      v_lo := 1;
      v_hi := 0;
    else
      v_lo := v_my_rank + 1;
      v_hi := v_my_rank + v_limit;
    end if;
  end if;

  with ranked as (
    select
      s.user_id,
      p.handle,
      p.display_name,
      p.avatar_url,
      s.points,
      s.answers_count,
      s.correct_count,
      rank() over (
        order by s.points desc, s.correct_count desc, s.updated_at asc
      ) as rnk
    from public.quiz_monthly_scores s
    join public.profiles p on p.id = s.user_id
    where s.year_month = v_month
      and p.suspended_at is null
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'userId', r.user_id,
        'handle', r.handle,
        'displayName', r.display_name,
        'avatarUrl', r.avatar_url,
        'points', r.points,
        'answersCount', r.answers_count,
        'correctCount', r.correct_count,
        'rank', r.rnk
      )
      order by r.rnk
    ),
    '[]'::jsonb
  )
  into v_entries
  from ranked r
  where r.rnk between v_lo and v_hi;

  return jsonb_build_object(
    'yearMonth', v_month,
    'mode', v_mode,
    'totalPlayers', coalesce(v_total, 0),
    'me', v_me,
    'entries', coalesce(v_entries, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.quiz_monthly_ranking_bundle(text, text, int) from public;
grant execute on function public.quiz_monthly_ranking_bundle(text, text, int) to authenticated;
