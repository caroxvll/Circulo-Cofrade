-- Cofradeo · apertura automática o manual de los hubs de temporada.
-- Requiere public.app_config (forum_pillar_covers.sql).

insert into public.app_config (key, value)
values
  ('season_cuaresma_mode', 'auto'),
  ('season_semana_santa_mode', 'auto'),
  ('season_semana_santa_manual_day', 'Domingo de Ramos')
on conflict (key) do nothing;

-- El modo manual de Semana Santa abre/cierra también el gate real de
-- publicación. En automático se conserva exactamente el cálculo por jornadas.
create or replace function public.ss_live_is_open(p_now timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(
      (select s.is_enabled from public.ss_live_settings s where s.id = 1),
      true
    )
    and case coalesce(
      (select c.value from public.app_config c
       where c.key = 'season_semana_santa_mode'),
      'auto'
    )
      when 'open' then true
      when 'closed' then false
      else (
        not exists (select 1 from public.ss_liturgical_days)
        or exists (
          select 1
          from public.ss_liturgical_days d
          where d.force_state = 'open'
             or (
               d.force_state = 'auto'
               and d.starts_at <= p_now
               and p_now < d.ends_at
             )
        )
      )
    end;
$$;

grant execute on function public.ss_live_is_open(timestamptz)
  to authenticated, anon;

-- En manual devuelve una jornada virtual con la etiqueta elegida. Así la app
-- puede mostrar «Hoy sales» solo a las hermandades de ese día.
create or replace function public.ss_current_liturgical_day(
  p_now timestamptz default now()
)
returns table (
  day_key text,
  label text,
  year int,
  starts_at timestamptz,
  ends_at timestamptz,
  force_state text,
  is_open boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with config as (
    select
      coalesce(
        (select c.value from public.app_config c
         where c.key = 'season_semana_santa_mode'),
        'auto'
      ) as mode,
      coalesce(
        nullif(
          (select c.value from public.app_config c
           where c.key = 'season_semana_santa_manual_day'),
          ''
        ),
        'Domingo de Ramos'
      ) as manual_day
  ),
  candidates as (
    select
      replace(lower(config.manual_day), ' ', '-') as day_key,
      config.manual_day as label,
      extract(year from p_now)::int as year,
      p_now as starts_at,
      p_now + interval '1 day' as ends_at,
      'open'::text as force_state,
      true as is_open,
      1000 as sort_order
    from config
    where config.mode = 'open'

    union all

    select
      d.day_key,
      d.label,
      d.year,
      d.starts_at,
      d.ends_at,
      d.force_state,
      true as is_open,
      d.sort_order
    from public.ss_liturgical_days d
    cross join config
    where config.mode not in ('open', 'closed')
      and (
        d.force_state = 'open'
        or (
          d.force_state = 'auto'
          and d.starts_at <= p_now
          and p_now < d.ends_at
        )
      )
  )
  select
    candidates.day_key,
    candidates.label,
    candidates.year,
    candidates.starts_at,
    candidates.ends_at,
    candidates.force_state,
    candidates.is_open
  from candidates
  order by candidates.year desc, candidates.sort_order desc
  limit 1;
$$;

grant execute on function public.ss_current_liturgical_day(timestamptz)
  to authenticated, anon;
