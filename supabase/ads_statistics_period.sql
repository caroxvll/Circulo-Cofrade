-- Informe de publicidad por periodo (mes / rango / todo).
-- Ejecutar en Supabase SQL Editor.

create or replace function public.get_ad_statistics(
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns table (
  id uuid,
  title text,
  sponsor_name text,
  placement text,
  priority int,
  max_impressions int,
  current_impressions int,
  tracked_impressions int,
  clicks int,
  ctr numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_staff_user(auth.uid()) then
    raise exception 'Solo personal de Junta';
  end if;

  return query
  select
    a.id,
    a.title,
    a.sponsor_name,
    a.placement,
    a.priority,
    a.max_impressions,
    a.current_impressions,
    count(distinct i.id)::int as tracked_impressions,
    count(distinct c.id)::int as clicks,
    case
      when count(distinct i.id) = 0 then 0::numeric
      else round(
        (count(distinct c.id)::numeric / count(distinct i.id)::numeric) * 100,
        2
      )
    end as ctr
  from public.ads a
  left join public.ad_impressions i
    on i.ad_id = a.id
    and (p_from is null or i.created_at >= p_from)
    and (p_to is null or i.created_at < p_to)
  left join public.ad_clicks c
    on c.ad_id = a.id
    and (p_from is null or c.created_at >= p_from)
    and (p_to is null or c.created_at < p_to)
  group by a.id
  order by tracked_impressions desc, a.sponsor_name, a.title;
end;
$$;

grant execute on function public.get_ad_statistics(timestamptz, timestamptz) to authenticated;
