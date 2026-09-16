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
  custom_icon_url text not null default '' check (char_length(custom_icon_url) <= 700),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.calendar_events
  add column if not exists custom_icon_url text not null default '';

alter table public.calendar_events
  drop constraint if exists calendar_events_custom_icon_url_check;

alter table public.calendar_events
  add constraint calendar_events_custom_icon_url_check
  check (char_length(custom_icon_url) <= 700);

alter table public.calendar_events
  add column if not exists cover_image_url text not null default '';

alter table public.calendar_events
  drop constraint if exists calendar_events_cover_image_url_check;

alter table public.calendar_events
  add constraint calendar_events_cover_image_url_check
  check (char_length(cover_image_url) <= 700);

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
        p.role in ('admin', 'editor')
        or e.created_by = p_user_id
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

-- ---------------------------------------------------------------------------
-- Storage: iconos personalizados de eventos
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-icons',
  'event-icons',
  true,
  1048576,
  array['image/svg+xml', 'image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Iconos de eventos públicos" on storage.objects;
create policy "Iconos de eventos públicos"
  on storage.objects for select
  using (bucket_id = 'event-icons');

drop policy if exists "Editor sube iconos de eventos" on storage.objects;
create policy "Editor sube iconos de eventos"
  on storage.objects for insert
  with check (
    bucket_id = 'event-icons'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.is_calendar_editor(auth.uid())
  );

drop policy if exists "Editor actualiza iconos de eventos" on storage.objects;
create policy "Editor actualiza iconos de eventos"
  on storage.objects for update
  using (
    bucket_id = 'event-icons'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.is_calendar_editor(auth.uid())
  );

drop policy if exists "Editor borra iconos de eventos" on storage.objects;
create policy "Editor borra iconos de eventos"
  on storage.objects for delete
  using (
    bucket_id = 'event-icons'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.is_calendar_editor(auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Storage: portadas de eventos (carrusel / miniaturas)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-covers',
  'event-covers',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Portadas de eventos públicas" on storage.objects;
create policy "Portadas de eventos públicas"
  on storage.objects for select
  using (bucket_id = 'event-covers');

drop policy if exists "Editor sube portadas de eventos" on storage.objects;
create policy "Editor sube portadas de eventos"
  on storage.objects for insert
  with check (
    bucket_id = 'event-covers'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.is_calendar_editor(auth.uid())
  );

drop policy if exists "Editor actualiza portadas de eventos" on storage.objects;
create policy "Editor actualiza portadas de eventos"
  on storage.objects for update
  using (
    bucket_id = 'event-covers'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.is_calendar_editor(auth.uid())
  );

drop policy if exists "Editor borra portadas de eventos" on storage.objects;
create policy "Editor borra portadas de eventos"
  on storage.objects for delete
  using (
    bucket_id = 'event-covers'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.is_calendar_editor(auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Biblioteca de escudos por organizador (reutilizable entre eventos)
-- ---------------------------------------------------------------------------
create table if not exists public.organizer_logos (
  organizer_key text primary key check (char_length(organizer_key) between 2 and 120),
  display_label text not null default '' check (char_length(display_label) <= 120),
  logo_url text not null check (char_length(logo_url) <= 700),
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.organizer_logos enable row level security;

drop policy if exists "Escudos de organizador legibles" on public.organizer_logos;
create policy "Escudos de organizador legibles"
  on public.organizer_logos for select
  using (true);

drop policy if exists "Editor guarda escudos de organizador" on public.organizer_logos;
create policy "Editor guarda escudos de organizador"
  on public.organizer_logos for insert
  with check (public.is_calendar_editor(auth.uid()));

drop policy if exists "Editor actualiza escudos de organizador" on public.organizer_logos;
create policy "Editor actualiza escudos de organizador"
  on public.organizer_logos for update
  using (public.is_calendar_editor(auth.uid()))
  with check (public.is_calendar_editor(auth.uid()));

drop policy if exists "Editor elimina escudos de organizador" on public.organizer_logos;
create policy "Editor elimina escudos de organizador"
  on public.organizer_logos for delete
  using (public.is_calendar_editor(auth.uid()));
