-- Cofradero · cuenta atrás litúrgica (override opcional desde Junta)
-- Ejecutar después de roles_v2.sql. Idempotente.

create table if not exists public.liturgical_countdown_settings (
  year int primary key check (year between 2020 and 2100),
  palm_sunday_date date,
  easter_sunday_date date,
  visible_days_before int not null default 60
    check (visible_days_before between 0 and 400),
  is_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.liturgical_countdown_settings enable row level security;

drop policy if exists "Cuenta atrás legible por todos" on public.liturgical_countdown_settings;
create policy "Cuenta atrás legible por todos"
  on public.liturgical_countdown_settings for select
  using (true);

drop policy if exists "Admin gestiona cuenta atrás" on public.liturgical_countdown_settings;
create policy "Admin gestiona cuenta atrás"
  on public.liturgical_countdown_settings for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Migración: ampliar rango (0 = solo desde Ramos; hasta 400 = ver desde ya).
alter table public.liturgical_countdown_settings
  drop constraint if exists liturgical_countdown_settings_visible_days_before_check;

alter table public.liturgical_countdown_settings
  add constraint liturgical_countdown_settings_visible_days_before_check
  check (visible_days_before between 0 and 400);
