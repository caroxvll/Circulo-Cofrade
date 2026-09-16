-- Cofradero · avisos en vivo de ensayos (Cuaresma)
-- Ejecutar en SQL Editor después de calendar_events.sql

create table if not exists public.event_live_updates (
  id uuid primary key default gen_random_uuid(),
  calendar_event_id uuid not null references public.calendar_events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  message text not null check (char_length(trim(message)) between 1 and 280),
  place_label text not null default '' check (char_length(place_label) <= 160),
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  constraint event_live_updates_coords_check check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  )
);

create index if not exists event_live_updates_event_created_idx
  on public.event_live_updates (calendar_event_id, created_at desc);

create index if not exists event_live_updates_user_created_idx
  on public.event_live_updates (user_id, created_at desc);

create or replace function public.can_post_event_live_update(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.calendar_events e
    where e.id = p_event_id
      and e.event_type = 'ensayo'
      and e.status = 'published'
      and date_trunc(
        'day',
        e.starts_at at time zone 'Europe/Madrid'
      ) = date_trunc(
        'day',
        now() at time zone 'Europe/Madrid'
      )
  );
$$;

alter table public.event_live_updates enable row level security;

drop policy if exists "Avisos en vivo legibles" on public.event_live_updates;
create policy "Avisos en vivo legibles"
  on public.event_live_updates for select
  to authenticated
  using (true);

drop policy if exists "Cofrade publica aviso en ensayo del día" on public.event_live_updates;
create policy "Cofrade publica aviso en ensayo del día"
  on public.event_live_updates for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.can_post_event_live_update(calendar_event_id)
  );

drop policy if exists "Usuario borra su aviso en vivo" on public.event_live_updates;
create policy "Usuario borra su aviso en vivo"
  on public.event_live_updates for delete
  to authenticated
  using (auth.uid() = user_id);
