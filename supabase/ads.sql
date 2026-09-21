-- Cofradero · patrocinios nativos internos
-- Ejecutar después de schema.sql.

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 80),
  description text not null default '' check (char_length(description) <= 180),
  image_url text,
  sponsor_logo_url text,
  calendar_event_id uuid references public.calendar_events (id) on delete set null,
  sponsor_name text not null default '' check (char_length(sponsor_name) <= 80),
  button_text text not null default 'Ver más' check (char_length(button_text) <= 30),
  target_url text not null,
  placement text not null check (
    placement in (
      'home',
      'forums_top',
      'forums_middle',
      'forums_event',
      'calendar',
      'search',
      'profile',
      'hermandades',
      'featured_topic',
      'noticias'
    )
  ),
  priority int not null default 1 check (priority between 1 and 100),
  max_impressions int not null check (max_impressions > 0),
  current_impressions int not null default 0 check (current_impressions >= 0),
  start_date timestamptz not null default now(),
  end_date timestamptz,
  active boolean not null default true,
  forum_id text,
  created_at timestamptz not null default now()
);

alter table public.ads
  add column if not exists sponsor_logo_url text;

alter table public.ads
  add column if not exists calendar_event_id uuid references public.calendar_events (id) on delete set null;

alter table public.ads
  add column if not exists forum_id text;

create index if not exists ads_placement_active_idx
  on public.ads (placement, active, priority desc);

create table if not exists public.ad_impressions (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  viewer_id text not null,
  created_at timestamptz not null default now()
);

create index if not exists ad_impressions_ad_created_idx
  on public.ad_impressions (ad_id, created_at desc);

create index if not exists ad_impressions_viewer_recent_idx
  on public.ad_impressions (ad_id, viewer_id, created_at desc);

create table if not exists public.ad_clicks (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  viewer_id text not null,
  created_at timestamptz not null default now()
);

create index if not exists ad_clicks_ad_created_idx
  on public.ad_clicks (ad_id, created_at desc);

alter table public.ads enable row level security;
alter table public.ad_impressions enable row level security;
alter table public.ad_clicks enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ad-assets',
  'ad-assets',
  true,
  4194304,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Assets anuncios lectura publica" on storage.objects;
create policy "Assets anuncios lectura publica"
  on storage.objects for select
  using (bucket_id = 'ad-assets');

drop policy if exists "Staff sube assets anuncios" on storage.objects;
create policy "Staff sube assets anuncios"
  on storage.objects for insert
  with check (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff actualiza assets anuncios" on storage.objects;
create policy "Staff actualiza assets anuncios"
  on storage.objects for update
  using (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  )
  with check (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff borra assets anuncios" on storage.objects;
create policy "Staff borra assets anuncios"
  on storage.objects for delete
  using (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Anuncios activos legibles" on public.ads;
create policy "Anuncios activos legibles"
  on public.ads for select
  using (
    active = true
    and start_date <= now()
    and (end_date is null or end_date >= now())
    and current_impressions < max_impressions
  );

drop policy if exists "Staff gestiona anuncios" on public.ads;
create policy "Staff gestiona anuncios"
  on public.ads for all
  using (public.is_staff_user(auth.uid()))
  with check (public.is_staff_user(auth.uid()));

drop policy if exists "Staff lee impresiones" on public.ad_impressions;
create policy "Staff lee impresiones"
  on public.ad_impressions for select
  using (public.is_staff_user(auth.uid()));

drop policy if exists "Staff lee clicks" on public.ad_clicks;
create policy "Staff lee clicks"
  on public.ad_clicks for select
  using (public.is_staff_user(auth.uid()));

create or replace function public.get_ad_for_placement(
  p_placement text,
  p_forum_id text default null
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

create or replace function public.register_ad_impression(
  p_ad_id uuid,
  p_viewer_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_exists boolean;
begin
  if p_viewer_id is null or length(trim(p_viewer_id)) = 0 then
    raise exception 'viewer_id requerido';
  end if;

  select exists (
    select 1
    from public.ad_impressions
    where ad_id = p_ad_id
      and viewer_id = p_viewer_id
      and created_at >= now() - interval '24 hours'
  )
  into v_exists;

  if v_exists then
    return false;
  end if;

  insert into public.ad_impressions (ad_id, user_id, viewer_id)
  values (p_ad_id, v_user_id, p_viewer_id);

  update public.ads
  set current_impressions = current_impressions + 1
  where id = p_ad_id
    and active = true
    and current_impressions < max_impressions;

  return true;
end;
$$;

create or replace function public.register_ad_click(
  p_ad_id uuid,
  p_viewer_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_viewer_id is null or length(trim(p_viewer_id)) = 0 then
    raise exception 'viewer_id requerido';
  end if;

  insert into public.ad_clicks (ad_id, user_id, viewer_id)
  values (p_ad_id, auth.uid(), p_viewer_id);
end;
$$;

create or replace view public.ad_statistics
with (security_invoker = true)
as
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
    when count(distinct i.id) = 0 then 0
    else round(
      (count(distinct c.id)::numeric / count(distinct i.id)::numeric) * 100,
      2
    )
  end as ctr
from public.ads a
left join public.ad_impressions i on i.ad_id = a.id
left join public.ad_clicks c on c.ad_id = a.id
group by a.id;

-- Ejemplo de patrocinio superior en Foros:
-- insert into public.ads (
--   title, description, sponsor_name, button_text, target_url,
--   placement, priority, max_impressions
-- ) values (
--   'Costales La Trasera',
--   'Todo para el costalero. Calidad y tradición desde 1998.',
--   'Costales La Trasera',
--   'Visitar tienda',
--   'https://example.com',
--   'forums_top',
--   10,
--   5000
-- );
