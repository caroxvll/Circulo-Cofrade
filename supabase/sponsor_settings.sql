-- Cofradeo · cupo máximo de empresas/marcas activas (configurable desde admin-web)
-- Ejecutar en Supabase SQL Editor. Idempotente.

create table if not exists public.sponsor_settings (
  id int primary key default 1 check (id = 1),
  max_active_companies int not null default 20
    check (max_active_companies between 1 and 100),
  updated_at timestamptz not null default now()
);

comment on table public.sponsor_settings is
  'Ajustes de patrocinios: cupo máximo de marcas activas (fila única id=1).';

comment on column public.sponsor_settings.max_active_companies is
  'Número máximo de empresas distintas con piezas en ads. Editable desde admin-web.';

insert into public.sponsor_settings (id, max_active_companies)
values (1, 20)
on conflict (id) do nothing;

alter table public.sponsor_settings enable row level security;

drop policy if exists "Admin lee ajustes de patrocinio" on public.sponsor_settings;
create policy "Admin lee ajustes de patrocinio"
  on public.sponsor_settings for select
  using (public.is_admin_user(auth.uid()));

drop policy if exists "Admin gestiona ajustes de patrocinio" on public.sponsor_settings;
create policy "Admin gestiona ajustes de patrocinio"
  on public.sponsor_settings for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));
