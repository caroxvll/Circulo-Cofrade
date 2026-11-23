-- Pulso de altas para Junta (admin). Día civil en Europe/Madrid.
-- SQL Editor · PRE y PROD.

create or replace function public.admin_signup_pulse()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_today date := ((timezone('Europe/Madrid', now())))::date;
  v_start date := v_today - 13;
  v_payload jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo un admin puede ver el pulso de altas';
  end if;

  with days as (
    select generate_series(v_start, v_today, interval '1 day')::date as d
  ),
  counted as (
    select
      ((timezone('Europe/Madrid', p.created_at)))::date as d,
      count(*)::int as n
    from public.profiles p
    where ((timezone('Europe/Madrid', p.created_at)))::date >= v_start
    group by 1
  ),
  series as (
    select
      to_char(days.d, 'YYYY-MM-DD') as date,
      coalesce(counted.n, 0) as count
    from days
    left join counted on counted.d = days.d
  ),
  totals as (
    select
      count(*)::int as total,
      count(*) filter (
        where coalesce(account_type, 'cofrade') = 'brotherhood'
      )::int as hermandades,
      count(*) filter (
        where coalesce(account_type, 'cofrade') <> 'brotherhood'
      )::int as cofrades,
      count(*) filter (
        where ((timezone('Europe/Madrid', created_at)))::date = v_today
      )::int as today,
      count(*) filter (
        where ((timezone('Europe/Madrid', created_at)))::date = v_today - 1
      )::int as yesterday,
      count(*) filter (
        where ((timezone('Europe/Madrid', created_at)))::date >= v_today - 6
      )::int as last7,
      count(*) filter (
        where ((timezone('Europe/Madrid', created_at)))::date >= v_today - 29
      )::int as last30
    from public.profiles
  )
  select jsonb_build_object(
    'today', totals.today,
    'yesterday', totals.yesterday,
    'last7', totals.last7,
    'last30', totals.last30,
    'total', totals.total,
    'cofrades', totals.cofrades,
    'hermandades', totals.hermandades,
    'days', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object('date', s.date, 'count', s.count)
          order by s.date
        )
        from series s
      ),
      '[]'::jsonb
    )
  )
  into v_payload
  from totals;

  return coalesce(v_payload, '{}'::jsonb);
end;
$$;

revoke all on function public.admin_signup_pulse() from public;
grant execute on function public.admin_signup_pulse() to authenticated;
