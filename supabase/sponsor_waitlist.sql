-- Cofradeo · lista de espera de empresas
-- Ejecutar en Supabase SQL Editor. Solo admins.
-- Las empresas activas siguen viniendo de la tabla `ads` (marcas distintas).
-- El cupo máximo se configura en sponsor_settings.max_active_companies.
-- Esta tabla guarda quién espera hueco cuando el cupo está lleno.

create table if not exists public.sponsor_waitlist (
  id uuid primary key default gen_random_uuid(),
  company_name text not null check (char_length(trim(company_name)) between 2 and 80),
  contact text not null default '' check (char_length(contact) <= 160),
  notes text not null default '' check (char_length(notes) <= 500),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists sponsor_waitlist_name_uidx
  on public.sponsor_waitlist (lower(trim(company_name)));

create index if not exists sponsor_waitlist_created_idx
  on public.sponsor_waitlist (created_at asc);

comment on table public.sponsor_waitlist is
  'Cola FIFO de marcas pendientes de entrar cuando el cupo (sponsor_settings) está lleno.';

alter table public.sponsor_waitlist enable row level security;

drop policy if exists "Admin gestiona lista de espera" on public.sponsor_waitlist;
create policy "Admin gestiona lista de espera"
  on public.sponsor_waitlist for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));
