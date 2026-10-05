-- Cofradeo · Estimación de audiencia para progreso X / Y en el admin
-- Ejecutar una vez en SQL Editor (idempotente).

alter table public.notification_dispatch_jobs
  add column if not exists audience_estimate int;

comment on column public.notification_dispatch_jobs.audience_estimate is
  'Estimación de destinatarios al procesar (para progreso X/Y en admin).';

create or replace function public.estimate_notification_dispatch_audience(
  p_job public.notification_dispatch_jobs
)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n int := 0;
  mode text := coalesce(p_job.audience_mode, 'follows');
begin
  perform set_config('row_security', 'off', true);

  if mode = 'pref' then
    select count(*)::int into n
    from public.profiles p
    where p.suspended_at is null
      and p.id is distinct from p_job.author_id
      and public.notify_pref_enabled(p.id, coalesce(p_job.audience_pref, 'calendar'));

  elsif mode = 'follows_hashtags' then
    select count(distinct f.follower_id)::int into n
    from public.follows f
    join public.profiles p on p.id = f.follower_id
    where f.target_type = 'hashtag'
      and lower(f.target_id) = any (
        select lower(t) from unnest(coalesce(p_job.audience_hashtags, array[]::text[])) as t
      )
      and p.suspended_at is null
      and f.follower_id is distinct from p_job.author_id
      and public.notify_pref_enabled(f.follower_id, coalesce(p_job.audience_pref, 'hashtags'))
      and (
        p_job.author_id is null
        or public.is_not_blocked(f.follower_id, p_job.author_id)
      );

  else
    select count(*)::int into n
    from public.follows f
    join public.profiles p on p.id = f.follower_id
    where f.target_type = coalesce(p_job.audience_target_type, 'forum')
      and f.target_id = coalesce(p_job.audience_target_id, 'noticias')
      and p.suspended_at is null
      and f.follower_id is distinct from p_job.author_id
      and (
        p_job.audience_pref is null
        or public.notify_pref_enabled(f.follower_id, p_job.audience_pref)
      )
      and (
        p_job.author_id is null
        or public.is_not_blocked(f.follower_id, p_job.author_id)
      )
      and (
        p_job.audience_official_category is null
        or f.notify_official_categories is null
        or p_job.audience_official_category = any (f.notify_official_categories)
      );
  end if;

  return coalesce(n, 0);
end;
$$;

create or replace function public.staff_fill_dispatch_audience_estimates()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.notification_dispatch_jobs%rowtype;
  n int := 0;
  est int;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  for r in
    select *
    from public.notification_dispatch_jobs
    where audience_estimate is null
      and status in ('pending', 'processing', 'done', 'failed')
    order by created_at desc
    limit 30
  loop
    est := public.estimate_notification_dispatch_audience(r);
    -- Si ya terminó, el total real no baja de lo procesado.
    if r.status = 'done' then
      est := greatest(est, coalesce(r.processed_count, 0));
    end if;
    update public.notification_dispatch_jobs
    set audience_estimate = est
    where id = r.id;
    n := n + 1;
  end loop;

  return n;
end;
$$;

revoke all on function public.estimate_notification_dispatch_audience(public.notification_dispatch_jobs) from public;
revoke all on function public.staff_fill_dispatch_audience_estimates() from public;
grant execute on function public.staff_fill_dispatch_audience_estimates() to authenticated;

notify pgrst, 'reload schema';
