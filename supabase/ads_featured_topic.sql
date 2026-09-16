-- Banner en temas destacados (Cuaresma / Semana Santa / Glorias).
-- Placement: featured_topic · segmentación opcional por topic_id.
-- Ejecutar en Supabase → SQL Editor.

alter table public.ads
  add column if not exists topic_id text;

create index if not exists ads_placement_topic_active_idx
  on public.ads (placement, topic_id, active, priority desc);

alter table public.ads drop constraint if exists ads_placement_check;

alter table public.ads
  add constraint ads_placement_check check (
    placement in (
      'home',
      'forums_top',
      'forums_middle',
      'forums_event',
      'calendar',
      'search',
      'profile',
      'hermandades',
      'featured_topic'
    )
  );

create or replace function public.get_ad_for_placement(
  p_placement text,
  p_forum_id text default null,
  p_topic_id text default null
)
returns setof public.ads
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  with eligible as (
    select a.*, sum(a.priority) over () as total_priority
    from public.ads a
    where a.placement = p_placement
      and a.active = true
      and a.start_date <= now()
      and (a.end_date is null or a.end_date >= now())
      and a.current_impressions < a.max_impressions
      and (
        p_forum_id is null
        or a.forum_id is null
        or a.forum_id = p_forum_id
      )
      and (
        p_topic_id is null
        or a.topic_id is null
        or a.topic_id = p_topic_id
      )
  ),
  pick as (
    select random() * coalesce(max(total_priority), 0) as ticket
    from eligible
  ),
  weighted as (
    select
      e.id,
      e.priority,
      e.created_at,
      sum(e.priority) over (order by e.priority desc, e.created_at asc) as cumulative
    from eligible e
  ),
  picked as (
    select w.id
    from weighted w, pick p
    where w.cumulative >= p.ticket
    order by w.cumulative asc
    limit 1
  )
  select a.*
  from public.ads a
  join picked on picked.id = a.id;
end;
$$;
