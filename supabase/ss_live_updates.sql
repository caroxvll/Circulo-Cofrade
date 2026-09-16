-- Cofradeo · avisos en directo de Semana Santa (Círculo Cofrade)
-- Ejecutar en SQL Editor después de profiles / forum_topics

create table if not exists public.ss_live_updates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null default 'general'
    check (kind in ('retraso', 'posicion', 'incidente', 'curiosidad', 'general')),
  hermandad_label text not null default ''
    check (char_length(hermandad_label) <= 120),
  message text not null
    check (char_length(trim(message)) between 1 and 280),
  place_label text not null default ''
    check (char_length(place_label) <= 160),
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  constraint ss_live_updates_coords_check check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  )
);

create index if not exists ss_live_updates_created_idx
  on public.ss_live_updates (created_at desc);

create index if not exists ss_live_updates_kind_created_idx
  on public.ss_live_updates (kind, created_at desc);

create index if not exists ss_live_updates_user_created_idx
  on public.ss_live_updates (user_id, created_at desc);

alter table public.ss_live_updates enable row level security;

drop policy if exists "Avisos SS legibles" on public.ss_live_updates;
create policy "Avisos SS legibles"
  on public.ss_live_updates for select
  to authenticated
  using (true);

drop policy if exists "Cofrade publica aviso SS" on public.ss_live_updates;
create policy "Cofrade publica aviso SS"
  on public.ss_live_updates for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Usuario borra su aviso SS" on public.ss_live_updates;
create policy "Usuario borra su aviso SS"
  on public.ss_live_updates for delete
  to authenticated
  using (auth.uid() = user_id);
