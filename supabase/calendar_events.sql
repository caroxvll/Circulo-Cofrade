-- Cofradero · calendario real + rol editor (hermandades / colaboradores)
-- Ejecutar en SQL Editor después de admin_roles.sql

-- ---------------------------------------------------------------------------
-- Rol editor (colaborador del calendario)
-- ---------------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('member', 'editor', 'moderator', 'admin'));

-- Ejemplos:
-- update public.profiles set role = 'editor' where handle = 'hermandad_macarena';
-- update public.profiles set role = 'editor' where handle = 'colaborador_juan';

create or replace function public.is_calendar_editor(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = p_user_id
      and role in ('editor', 'admin')
      and suspended_at is null
  );
$$;

-- ---------------------------------------------------------------------------
-- Tabla de eventos (antes de can_manage_calendar_event)
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 120),
  subtitle text not null default '' check (char_length(subtitle) <= 240),
  event_type text not null check (
    event_type in ('procesion', 'gloria', 'ensayo', 'iguala', 'concierto', 'evento')
  ),
  starts_at timestamptz not null,
  day_label text,
  location text not null default '' check (char_length(location) <= 160),
  organizer_label text not null default '' check (char_length(organizer_label) <= 120),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists calendar_events_starts_at_idx
  on public.calendar_events (starts_at);

-- Tras crear la tabla (PostgreSQL valida el FROM al definir funciones SQL)
create or replace function public.can_manage_calendar_event(
  p_user_id uuid,
  p_event_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.calendar_events e
    join public.profiles p on p.id = p_user_id
    where e.id = p_event_id
      and p.suspended_at is null
      and (
        p.role = 'admin'
        or (p.role = 'editor' and e.created_by = p_user_id)
      )
  );
$$;

alter table public.calendar_events enable row level security;

drop policy if exists "Eventos legibles por todos" on public.calendar_events;
create policy "Eventos legibles por todos"
  on public.calendar_events for select
  using (true);

drop policy if exists "Editor crea eventos" on public.calendar_events;
create policy "Editor crea eventos"
  on public.calendar_events for insert
  with check (public.is_calendar_editor(auth.uid()));

drop policy if exists "Editor gestiona sus eventos" on public.calendar_events;
create policy "Editor gestiona sus eventos"
  on public.calendar_events for update
  using (public.can_manage_calendar_event(auth.uid(), id))
  with check (public.can_manage_calendar_event(auth.uid(), id));

drop policy if exists "Editor borra sus eventos" on public.calendar_events;
create policy "Editor borra sus eventos"
  on public.calendar_events for delete
  using (public.can_manage_calendar_event(auth.uid(), id));
