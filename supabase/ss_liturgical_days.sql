-- Cofradeo · jornadas litúrgicas Semana Santa (abrir / cerrar desde admin)
-- Ejecutar en SQL Editor (PRE/PROD). Idempotente.
-- Zona horaria de referencia: Europe/Madrid.

-- ─── Kill switch global del en directo ──────────────────────────────────────

create table if not exists public.ss_live_settings (
  id smallint primary key default 1 check (id = 1),
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.ss_live_settings (id, is_enabled)
values (1, true)
on conflict (id) do nothing;

alter table public.ss_live_settings enable row level security;

drop policy if exists "SS live settings legible" on public.ss_live_settings;
create policy "SS live settings legible"
  on public.ss_live_settings for select
  to authenticated
  using (true);

drop policy if exists "Admin gestiona SS live settings" on public.ss_live_settings;
create policy "Admin gestiona SS live settings"
  on public.ss_live_settings for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- ─── Jornadas por año ─────────────────────────────────────────────────────

create table if not exists public.ss_liturgical_days (
  id uuid primary key default gen_random_uuid(),
  year int not null check (year between 2020 and 2100),
  day_key text not null
    check (char_length(day_key) between 2 and 40),
  label text not null
    check (char_length(trim(label)) between 2 and 80),
  sort_order int not null,
  easter_offset int not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  force_state text not null default 'auto'
    check (force_state in ('auto', 'open', 'closed')),
  updated_at timestamptz not null default now(),
  constraint ss_liturgical_days_window_check check (ends_at > starts_at),
  unique (year, day_key)
);

create index if not exists ss_liturgical_days_year_sort_idx
  on public.ss_liturgical_days (year, sort_order);

create index if not exists ss_liturgical_days_window_idx
  on public.ss_liturgical_days (starts_at, ends_at);

alter table public.ss_liturgical_days enable row level security;

drop policy if exists "Jornadas SS legibles" on public.ss_liturgical_days;
create policy "Jornadas SS legibles"
  on public.ss_liturgical_days for select
  to authenticated
  using (true);

drop policy if exists "Admin gestiona jornadas SS" on public.ss_liturgical_days;
create policy "Admin gestiona jornadas SS"
  on public.ss_liturgical_days for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- ¿Está abierto el en directo ahora?
-- Si aún no hay jornadas configuradas → abierto (compatibilidad).
create or replace function public.ss_live_is_open(p_now timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((select s.is_enabled from public.ss_live_settings s where s.id = 1), true)
    and (
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
    );
$$;

grant execute on function public.ss_live_is_open(timestamptz) to authenticated, anon;

-- Jornada activa (si hay varias, la de mayor sort_order / más reciente)
create or replace function public.ss_current_liturgical_day(p_now timestamptz default now())
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
  select
    d.day_key,
    d.label,
    d.year,
    d.starts_at,
    d.ends_at,
    d.force_state,
    (
      d.force_state = 'open'
      or (
        d.force_state = 'auto'
        and d.starts_at <= p_now
        and p_now < d.ends_at
      )
    ) as is_open
  from public.ss_liturgical_days d
  where d.force_state = 'open'
     or (
       d.force_state = 'auto'
       and d.starts_at <= p_now
       and p_now < d.ends_at
     )
  order by d.year desc, d.sort_order desc
  limit 1;
$$;

grant execute on function public.ss_current_liturgical_day(timestamptz) to authenticated, anon;

-- Upsert de jornadas (evita fallos de onConflict / RLS en el cliente)
create or replace function public.admin_upsert_ss_liturgical_days(p_rows jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int := 0;
  r jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede generar jornadas';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows debe ser un array JSON';
  end if;

  for r in select * from jsonb_array_elements(p_rows)
  loop
    insert into public.ss_liturgical_days (
      year, day_key, label, sort_order, easter_offset,
      starts_at, ends_at, force_state, updated_at
    ) values (
      (r->>'year')::int,
      r->>'day_key',
      r->>'label',
      (r->>'sort_order')::int,
      (r->>'easter_offset')::int,
      (r->>'starts_at')::timestamptz,
      (r->>'ends_at')::timestamptz,
      coalesce(nullif(r->>'force_state', ''), 'auto'),
      coalesce((r->>'updated_at')::timestamptz, now())
    )
    on conflict (year, day_key) do update set
      label = excluded.label,
      sort_order = excluded.sort_order,
      easter_offset = excluded.easter_offset,
      starts_at = excluded.starts_at,
      ends_at = excluded.ends_at,
      -- conserva force_state si el cliente no lo manda; si lo manda, respétalo
      force_state = coalesce(excluded.force_state, public.ss_liturgical_days.force_state),
      updated_at = excluded.updated_at;
    n := n + 1;
  end loop;

  return n;
end;
$$;

grant execute on function public.admin_upsert_ss_liturgical_days(jsonb) to authenticated;

-- Gate de publicación (además del check en app)
drop policy if exists "Cofrade publica aviso SS" on public.ss_live_updates;
create policy "Cofrade publica aviso SS"
  on public.ss_live_updates for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.ss_live_is_open()
  );

alter table public.ss_liturgical_days replica identity full;
alter table public.ss_live_settings replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.ss_liturgical_days;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.ss_live_settings;
exception
  when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
