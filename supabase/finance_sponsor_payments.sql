-- Cofradeo · finanzas de patrocinios (ingresos + gastos)
-- Ejecutar en Supabase SQL Editor. Solo admins.

-- ---------------------------------------------------------------------------
-- Ingresos: cobros a empresas / marcas
-- status: pending | paid | unpaid
-- ---------------------------------------------------------------------------
create table if not exists public.sponsor_payments (
  id uuid primary key default gen_random_uuid(),
  sponsor_name text not null check (char_length(trim(sponsor_name)) between 2 and 80),
  concept text not null default '' check (char_length(concept) <= 160),
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'unpaid')),
  period_month date not null,
  due_date date,
  paid_at date,
  notes text not null default '' check (char_length(notes) <= 500),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.sponsor_payments.period_month is
  'Primer día del mes de facturación (ej. 2026-09-01).';

create index if not exists sponsor_payments_period_idx
  on public.sponsor_payments (period_month desc, status);

create index if not exists sponsor_payments_sponsor_idx
  on public.sponsor_payments (sponsor_name);

alter table public.sponsor_payments enable row level security;

drop policy if exists "Admin gestiona cobros patrocinio" on public.sponsor_payments;
create policy "Admin gestiona cobros patrocinio"
  on public.sponsor_payments for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- ---------------------------------------------------------------------------
-- Gastos: costes de plataforma / operación
-- ---------------------------------------------------------------------------
create table if not exists public.finance_expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'general'
    check (category in ('infra', 'ads', 'tools', 'legal', 'other', 'general')),
  concept text not null check (char_length(trim(concept)) between 2 and 160),
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  expense_date date not null default (current_date),
  notes text not null default '' check (char_length(notes) <= 500),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists finance_expenses_date_idx
  on public.finance_expenses (expense_date desc);

alter table public.finance_expenses enable row level security;

drop policy if exists "Admin gestiona gastos" on public.finance_expenses;
create policy "Admin gestiona gastos"
  on public.finance_expenses for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));
