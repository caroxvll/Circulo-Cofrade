-- Cofradero · eventos guardados por usuario
-- Ejecutar en SQL Editor después de calendar_events.sql

create table if not exists public.event_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  event_id uuid not null references public.calendar_events (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, event_id)
);

create index if not exists event_bookmarks_user_id_idx
  on public.event_bookmarks (user_id);

create index if not exists event_bookmarks_event_id_idx
  on public.event_bookmarks (event_id);

alter table public.event_bookmarks enable row level security;

drop policy if exists "Usuario gestiona sus eventos guardados" on public.event_bookmarks;

create policy "Usuario gestiona sus eventos guardados"
  on public.event_bookmarks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
