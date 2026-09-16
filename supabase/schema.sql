-- Cofradero · esquema inicial Supabase (Fase 8)
-- Ejecutar en SQL Editor del dashboard de Supabase.

-- ── Perfiles ────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text unique not null,
  display_name text not null check (char_length(display_name) between 2 and 40),
  bio text default '' check (char_length(bio) <= 160),
  avatar_url text,
  account_type text not null default 'cofrade'
    check (account_type in ('cofrade', 'brotherhood')),
  verified boolean not null default false,
  address text default '',
  founded_label text default '',
  website text default '',
  publication_count int not null default 0,
  follower_count int not null default 0,
  suspended_at timestamptz,
  suspended_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Perfiles públicos legibles"
  on public.profiles for select using (true);

create policy "Usuario inserta su perfil"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Usuario actualiza su perfil"
  on public.profiles for update
  using (auth.uid() = id);

-- La verificación es administrativa; la app no debe permitir autoverificación.
create or replace function public.prevent_profile_verified_self_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verified is distinct from old.verified
     and auth.uid() is not null
     and auth.uid() = old.id then
    raise exception 'No puedes cambiar tu propia verificación desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_verified_guard on public.profiles;
create trigger on_profile_verified_guard
  before update on public.profiles
  for each row execute function public.prevent_profile_verified_self_change();

-- Trigger: crear perfil al registrarse
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  raw_handle text;
begin
  raw_handle := coalesce(
    new.raw_user_meta_data ->> 'handle',
    split_part(new.email, '@', 1)
  );
  raw_handle := lower(regexp_replace(raw_handle, '[^a-z0-9_]', '', 'g'));
  if raw_handle = '' then
    raw_handle := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  insert into public.profiles (id, handle, display_name)
  values (
    new.id,
    raw_handle,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Seguimientos (hashtags + perfiles + hilos) ──────────────────────────────

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('hashtag', 'profile', 'topic')),
  target_id text not null,
  created_at timestamptz not null default now(),
  unique (follower_id, target_type, target_id)
);

alter table public.follows enable row level security;

create policy "Usuario gestiona sus follows"
  on public.follows for all
  using (auth.uid() = follower_id)
  with check (auth.uid() = follower_id);

-- ── Notificaciones ──────────────────────────────────────────────────────────

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  subtitle text not null default '',
  payload jsonb default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Usuario lee sus notificaciones"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Usuario marca leídas"
  on public.notifications for update
  using (auth.uid() = user_id);

-- ── Bloqueos y reportes ─────────────────────────────────────────────────────

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table public.blocks enable row level security;

create policy "Usuario gestiona bloqueos"
  on public.blocks for all
  using (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null,
  target_id text not null,
  reason text not null,
  details text default '',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "Usuario crea reportes"
  on public.reports for insert
  with check (auth.uid() = reporter_id);

-- ── Foros (pilares, temas, respuestas) ──────────────────────────────────────

create table if not exists public.forum_pillars (
  id text primary key,
  name text not null,
  description text not null default '',
  icon_key text not null default 'church',
  icon_image_url text,
  sort_order int not null default 0,
  topic_count int not null default 0,
  message_count int not null default 0,
  last_activity_at timestamptz,
  -- FK a forum_topics se añade después (evita 42P01 en proyecto vacío)
  last_topic_id text,
  last_topic_title text,
  is_enabled boolean not null default true,
  is_active boolean not null default false,
  locked_label text,
  created_at timestamptz not null default now()
);

create table if not exists public.forum_topics (
  id text primary key,
  forum_id text not null references public.forum_pillars (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  author_handle text not null,
  title text not null,
  excerpt text not null,
  body text not null,
  is_resolved boolean not null default false,
  view_count int not null default 0,
  comment_count int not null default 0,
  status text not null default 'pending'
    check (status in ('pending', 'published', 'rejected')),
  is_pinned boolean not null default false,
  pin_sort_order int not null default 0,
  is_system boolean not null default false,
  season_key text
    check (
      season_key is null
      or season_key in ('cuaresma', 'semana_santa', 'glorias')
    ),
  icon_key text,
  cover_image_url text,
  is_listed boolean not null default true,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'forum_pillars_last_topic_id_fkey'
  ) then
    alter table public.forum_pillars
      add constraint forum_pillars_last_topic_id_fkey
      foreign key (last_topic_id)
      references public.forum_topics (id)
      on delete set null;
  end if;
end $$;

create table if not exists public.forum_replies (
  id uuid primary key default gen_random_uuid(),
  topic_id text not null references public.forum_topics (id) on delete cascade,
  author_id uuid references public.profiles (id) on delete set null,
  author_handle text not null,
  content text not null check (char_length(content) between 1 and 4000),
  is_official boolean not null default false,
  official_category text
    check (
      official_category is null
      or official_category in (
        'noticia', 'culto', 'acto', 'patrimonio'
      )
    ),
  like_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists forum_topics_forum_id_idx on public.forum_topics (forum_id);
create index if not exists forum_topics_created_at_idx on public.forum_topics (created_at desc);
create index if not exists forum_replies_topic_id_idx on public.forum_replies (topic_id);

alter table public.forum_pillars enable row level security;
alter table public.forum_topics enable row level security;
alter table public.forum_replies enable row level security;

drop policy if exists "Pilares legibles por todos" on public.forum_pillars;
create policy "Pilares legibles por todos"
  on public.forum_pillars for select using (true);

drop policy if exists "Temas publicados o propios" on public.forum_topics;
drop policy if exists "Temas legibles por todos" on public.forum_topics;
create policy "Temas publicados o propios"
  on public.forum_topics for select
  using (
    status = 'published'
    or author_id = auth.uid()
  );

drop policy if exists "Usuarios autenticados crean temas" on public.forum_topics;
create policy "Usuarios autenticados crean temas"
  on public.forum_topics for insert
  with check (
    auth.uid() is not null
    and author_id = auth.uid()
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Respuestas legibles por todos" on public.forum_replies;
create policy "Respuestas legibles por todos"
  on public.forum_replies for select using (true);

drop policy if exists "Usuarios autenticados responden" on public.forum_replies;
create policy "Usuarios autenticados responden"
  on public.forum_replies for insert
  with check (
    auth.uid() is not null
    and author_id = auth.uid()
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

-- Actualizar contador de respuestas al insertar
create or replace function public.handle_new_forum_reply()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.forum_topics
  set comment_count = comment_count + 1
  where id = new.topic_id;
  return new;
end;
$$;

drop trigger if exists on_forum_reply_created on public.forum_replies;
create trigger on_forum_reply_created
  after insert on public.forum_replies
  for each row execute function public.handle_new_forum_reply();

create or replace function public.handle_forum_reply_deleted()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.forum_topics
  set comment_count = greatest(comment_count - 1, 0)
  where id = old.topic_id;
  return old;
end;
$$;

drop trigger if exists on_forum_reply_deleted on public.forum_replies;
create trigger on_forum_reply_deleted
  after delete on public.forum_replies
  for each row execute function public.handle_forum_reply_deleted();
