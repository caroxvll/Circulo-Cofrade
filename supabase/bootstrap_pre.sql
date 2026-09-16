-- Cofradeo · BOOTSTRAP PRE (esquema + catálogo)
-- Generado por scripts/build-bootstrap-pre.mjs — no editar a mano; regenera el script.
--
-- SOLO para proyecto PRE vacío (u otro entorno de pruebas).
-- NO ejecutar en producción.
--
-- Qué hace: tablas, RLS, triggers, foros base, hermandades, ads, quiz, etc.
-- Qué NO hace: usuarios reales de prod, temas de usuarios, auth Google/FCM.
--
-- Tras ejecutarlo:
-- 1) Auth → Email ON (en pre puedes desactivar "Confirm email")
-- 2) Regístrate en la app/admin apuntando a env.pre.json
-- 3) update public.profiles set role = 'admin' where handle = 'tu_handle';
--
-- Si falla a mitad: copia el error, NO re-ejecutes todo a ciegas (pregunta).


-- ###########################################################################
-- FILE: schema.sql
-- ###########################################################################

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

drop policy if exists "Perfiles públicos legibles" on public.profiles;
create policy "Perfiles públicos legibles"
  on public.profiles for select using (true);

drop policy if exists "Usuario inserta su perfil" on public.profiles;
create policy "Usuario inserta su perfil"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "Usuario actualiza su perfil" on public.profiles;
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

drop policy if exists "Usuario gestiona sus follows" on public.follows;
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

drop policy if exists "Usuario lee sus notificaciones" on public.notifications;
create policy "Usuario lee sus notificaciones"
  on public.notifications for select
  using (auth.uid() = user_id);

drop policy if exists "Usuario marca leídas" on public.notifications;
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

drop policy if exists "Usuario gestiona bloqueos" on public.blocks;
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

drop policy if exists "Usuario crea reportes" on public.reports;
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


-- ###########################################################################
-- INLINE: pilares base
-- ###########################################################################

-- ---------------------------------------------------------------------------
-- Pilares base (Círculo / Pentagrama / Martillo) — ya no viven en seed.sql
-- ---------------------------------------------------------------------------
insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active
) values
  ('foro-cofradiero', 'Círculo Cofrade', 'La tertulia cofrade de Sevilla, los 365 días del año.', 'church', 1, 0, 0, true, true),
  ('pentagrama-cofrade', 'Pentagrama Cofrade', 'Agrupaciones, cornetas y tambores, bandas de música y repertorios.', 'music_note', 2, 0, 0, true, true),
  ('martillo-trabajadera', 'Martillo y Trabajadera', 'La actualidad de los capataces y el mundo del costal.', 'workspace_premium_outlined', 3, 0, 0, true, true)
on conflict (id) do nothing;


-- ###########################################################################
-- FILE: notifications_triggers.sql
-- ###########################################################################

-- Cofradero · notificaciones automáticas (Fase 8b)
-- Ejecutar en SQL Editor después de schema.sql + seed.sql
-- Si ya lo ejecutaste antes, vuelve a ejecutar ESTE archivo completo (versión corregida).

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
begin
  -- Permite insertar notificaciones para otros usuarios (el trigger no tiene sesión propia)
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_topic_text := lower(
    regexp_replace(
      coalesce(v_topic.title, '') || ' ' ||
      coalesce(v_topic.excerpt, '') || ' ' ||
      coalesce(v_topic.body, ''),
      '[\s#]+',
      '',
      'g'
    )
  );

  -- Avisar al autor del tema (si tiene cuenta y no es el mismo que responde)
  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
    );
  end if;

  -- Avisar a quienes siguen un hashtag que aparece en el tema
  -- Nota: NO se notifica a quien publica la respuesta (evita auto-notificación)
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  -- Avisar a quienes siguen el hilo (el autor ya recibe user_reply)
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: storage_avatars.sql
-- ###########################################################################

-- Cofradero · bucket avatares (Fase 8c)
-- Ejecutar en SQL Editor después de schema.sql

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatares públicos" on storage.objects;
create policy "Avatares públicos"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "Usuario sube su avatar" on storage.objects;
create policy "Usuario sube su avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Usuario actualiza su avatar" on storage.objects;
create policy "Usuario actualiza su avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Usuario borra su avatar" on storage.objects;
create policy "Usuario borra su avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Contador de seguidores al seguir/dejar de seguir un perfil
create or replace function public.handle_profile_follow_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.target_type = 'profile' then
    update public.profiles
    set follower_count = follower_count + 1
    where id::text = new.target_id;
  elsif tg_op = 'DELETE' and old.target_type = 'profile' then
    update public.profiles
    set follower_count = greatest(follower_count - 1, 0)
    where id::text = old.target_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists on_profile_follow_count on public.follows;
create trigger on_profile_follow_count
  after insert or delete on public.follows
  for each row execute function public.handle_profile_follow_count();


-- ###########################################################################
-- FILE: notifications_delete_policy.sql
-- ###########################################################################

-- Cofradero · permitir borrar notificaciones propias (Fase 8e)
-- Ejecutar en SQL Editor si aún no tienes política DELETE

drop policy if exists "Usuario borra sus notificaciones" on public.notifications;
create policy "Usuario borra sus notificaciones"
  on public.notifications for delete
  using (auth.uid() = user_id);


-- ###########################################################################
-- FILE: forum_subreplies_and_follow_notify.sql
-- ###########################################################################

-- Cofradero · subrespuestas + notificación al seguir perfil (Fase 8f parcial)
-- Ejecutar en SQL Editor

-- Subrespuestas (responder a una respuesta concreta)
alter table public.forum_replies
  add column if not exists parent_reply_id uuid
  references public.forum_replies (id) on delete cascade;

create index if not exists forum_replies_parent_id_idx
  on public.forum_replies (parent_reply_id);

-- Notificar al usuario cuando alguien le sigue
create or replace function public.notify_on_profile_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower record;
begin
  if new.target_type <> 'profile' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select display_name, handle
  into v_follower
  from public.profiles
  where id = new.follower_id;

  if not found then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    new.target_id::uuid,
    'new_follower',
    'Nuevo seguidor',
    coalesce(v_follower.display_name, v_follower.handle) || ' empezó a seguirte',
    jsonb_build_object('profileId', new.follower_id::text)
  );

  return new;
end;
$$;

drop trigger if exists on_profile_follow_notify on public.follows;
create trigger on_profile_follow_notify
  after insert on public.follows
  for each row execute function public.notify_on_profile_follow();


-- ###########################################################################
-- FILE: reply_likes_and_moderation.sql
-- ###########################################################################

-- Cofradero · likes en respuestas (Fase 8f)
-- Ejecutar en SQL Editor

create table if not exists public.forum_reply_likes (
  reply_id uuid not null references public.forum_replies (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reply_id, user_id)
);

alter table public.forum_reply_likes enable row level security;

drop policy if exists "Likes legibles por todos" on public.forum_reply_likes;
create policy "Likes legibles por todos"
  on public.forum_reply_likes for select using (true);

drop policy if exists "Usuario da me gusta si no suspendido" on public.forum_reply_likes;
create policy "Usuario da me gusta si no suspendido"
  on public.forum_reply_likes for insert
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario quita sus me gusta" on public.forum_reply_likes;
create policy "Usuario quita sus me gusta"
  on public.forum_reply_likes for delete
  using (auth.uid() = user_id);

create or replace function public.sync_reply_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.forum_replies
    set like_count = like_count + 1
    where id = new.reply_id;
  elsif tg_op = 'DELETE' then
    update public.forum_replies
    set like_count = greatest(like_count - 1, 0)
    where id = old.reply_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists on_reply_like_count on public.forum_reply_likes;
create trigger on_reply_like_count
  after insert or delete on public.forum_reply_likes
  for each row execute function public.sync_reply_like_count();


-- ###########################################################################
-- FILE: reply_reactions.sql
-- ###########################################################################

-- Cofradero · reacciones en respuestas (extiende forum_reply_likes)
-- Ejecutar después de reply_likes_and_moderation.sql
-- Luego ejecuta reply_reactions_emoji.sql (emojis + Realtime).

alter table public.forum_reply_likes
  add column if not exists reaction text not null default 'heart';

-- Quita constraint antiguo si existe (p. ej. re-ejecución o datos mixtos).
alter table public.forum_reply_likes
  drop constraint if exists forum_reply_likes_reaction_check;

comment on column public.forum_reply_likes.reaction is
  'Reacción (emoji unicode tras reply_reactions_emoji.sql)';

drop policy if exists "Usuario cambia su reacción" on public.forum_reply_likes;
create policy "Usuario cambia su reacción"
  on public.forum_reply_likes for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

create or replace function public.sync_reply_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.forum_replies
    set like_count = like_count + 1
    where id = new.reply_id;
  elsif tg_op = 'DELETE' then
    update public.forum_replies
    set like_count = greatest(like_count - 1, 0)
    where id = old.reply_id;
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function public.reply_reaction_counts(p_reply_ids uuid[])
returns table (reply_id uuid, reaction text, reaction_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select l.reply_id, l.reaction, count(*)::bigint
  from public.forum_reply_likes l
  where l.reply_id = any (p_reply_ids)
  group by l.reply_id, l.reaction;
$$;

grant execute on function public.reply_reaction_counts(uuid[]) to authenticated, anon;


-- ###########################################################################
-- FILE: reply_reactions_emoji.sql
-- ###########################################################################

-- Cofradero · reacciones como emoji (ejecutar tras reply_reactions.sql)
-- Sin este script la app no puede guardar ❤️, 👏, 🤗, etc.

alter table public.forum_reply_likes
  drop constraint if exists forum_reply_likes_reaction_check;

-- Migrar ids legacy ANTES de crear el nuevo check.
update public.forum_reply_likes
set reaction = case reaction
  when 'heart' then '❤️'
  when 'pray' then '🙏'
  when 'candle' then '🕯️'
  when 'amen' then '✨'
  when 'clap' then '👏'
  when 'moved' then '😢'
  when 'dislike' then '👎'
  when 'thanks' then '🤗'
  when '🫶' then '🤗'
  else reaction
end;

alter table public.forum_reply_likes
  add constraint forum_reply_likes_reaction_check
  check (char_length(reaction) >= 1 and char_length(reaction) <= 16);

comment on column public.forum_reply_likes.reaction is
  'Emoji unicode de la reacción';

alter table public.forum_reply_likes
  alter column reaction set default '❤️';

-- Realtime: otras pantallas ven reacciones al instante.
do $$
begin
  alter publication supabase_realtime add table public.forum_reply_likes;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- FILE: notification_social.sql
-- ###########################################################################

-- Cofradero · user_post, menciones @handle y preferencias in-app (Opción B)
-- Ejecutar en SQL Editor después de schema.sql, notifications_triggers.sql y topic_follows.sql

-- ---------------------------------------------------------------------------
-- Preferencias (tabla compartida con push Fase 9)
-- ---------------------------------------------------------------------------
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  notify_hashtags boolean not null default true,
  notify_profiles boolean not null default true,
  notify_topics boolean not null default true,
  notify_mentions boolean not null default true,
  notify_followers boolean not null default false,
  notify_calendar boolean not null default false,
  push_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences
  add column if not exists notify_topics boolean not null default true;

alter table public.notification_preferences enable row level security;

drop policy if exists "Usuario lee y edita sus preferencias"
  on public.notification_preferences;
create policy "Usuario lee y edita sus preferencias"
  on public.notification_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into public.notification_preferences (user_id)
select id from public.profiles
on conflict (user_id) do nothing;

create or replace function public.handle_new_profile_preferences()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created_preferences on public.profiles;
create trigger on_profile_created_preferences
  after insert on public.profiles
  for each row execute function public.handle_new_profile_preferences();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    else true
  end;
$$;

create or replace function public.is_not_blocked(p_viewer_id uuid, p_author_id uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select not exists (
    select 1
    from public.blocks b
    where b.blocker_id = p_viewer_id
      and b.blocked_id = p_author_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Seguidores del autor cuando se publica un tema
-- ---------------------------------------------------------------------------
create or replace function public.notify_followers_on_topic_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author record;
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  if new.author_id is null then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select handle, display_name
  into v_author
  from public.profiles
  where id = new.author_id;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'user_post',
    coalesce(v_author.display_name, '@' || v_author.handle) || ' publicó',
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id,
      'profileId', new.author_id::text
    )
  from public.follows f
  where f.target_type = 'profile'
    and f.target_id = new.author_id::text
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'profiles')
    and public.is_not_blocked(f.follower_id, new.author_id);

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_followers on public.forum_topics;
create trigger on_topic_published_notify_followers
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_followers_on_topic_published();

-- ---------------------------------------------------------------------------
-- Seguidores de hashtag cuando se publica un tema nuevo
-- ---------------------------------------------------------------------------
create or replace function public.notify_hashtag_followers_on_topic_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nueva conversación en ' || f.target_id,
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and (
      new.author_id is null
      or public.is_not_blocked(f.follower_id, new.author_id)
    )
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(new.title, '') || ' ' ||
        coalesce(new.excerpt, '') || ' ' ||
        coalesce(new.body, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_hashtags on public.forum_topics;
create trigger on_topic_published_notify_hashtags
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_hashtag_followers_on_topic_published();

-- ---------------------------------------------------------------------------
-- Respuestas: hashtags, hilos, autor del tema, menciones @handle
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_handle text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  -- Autor del tema (siempre, salvo auto-respuesta)
  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  -- Hashtags seguidos
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(v_topic.title, '') || ' ' ||
        coalesce(v_topic.excerpt, '') || ' ' ||
        coalesce(v_topic.body, '') || ' ' ||
        coalesce(new.content, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  -- Hilos seguidos
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  -- Menciones @handle en el texto de la respuesta
  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();

-- ---------------------------------------------------------------------------
-- Nuevo seguidor (respeta preferencia notify_followers)
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_profile_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower record;
begin
  if new.target_type <> 'profile' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  if not public.notify_pref_enabled(new.target_id::uuid, 'followers') then
    return new;
  end if;

  select display_name, handle
  into v_follower
  from public.profiles
  where id = new.follower_id;

  if not found then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    new.target_id::uuid,
    'new_follower',
    'Nuevo seguidor',
    coalesce(v_follower.display_name, v_follower.handle) || ' empezó a seguirte',
    jsonb_build_object('profileId', new.follower_id::text)
  );

  return new;
end;
$$;

drop trigger if exists on_profile_follow_notify on public.follows;
create trigger on_profile_follow_notify
  after insert on public.follows
  for each row execute function public.notify_on_profile_follow();


-- ###########################################################################
-- FILE: reply_reaction_notify.sql
-- ###########################################################################

-- Cofradero · aviso al autor + listado de reacciones
-- Ejecutar tras reply_reactions_emoji.sql (o reply_reactions_fix.sql)

alter table public.notification_preferences
  add column if not exists notify_reactions boolean not null default true;

create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    else true
  end;
$$;

create or replace function public.notify_on_reply_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply record;
  v_topic record;
  v_reactor record;
  v_existing record;
  v_latest_handle text;
  v_first_handle text;
  v_count int;
  v_subtitle text;
  v_payload jsonb;
begin
  perform set_config('row_security', 'off', true);

  select id, topic_id, author_id, official_category
  into v_reply
  from public.forum_replies
  where id = new.reply_id;

  if not found or v_reply.author_id is null then
    return new;
  end if;

  if v_reply.author_id = new.user_id then
    return new;
  end if;

  if not public.is_not_blocked(v_reply.author_id, new.user_id) then
    return new;
  end if;

  if not public.notify_pref_enabled(v_reply.author_id, 'reactions') then
    return new;
  end if;

  select id, forum_id, title
  into v_topic
  from public.forum_topics
  where id = v_reply.topic_id;

  if not found then
    return new;
  end if;

  select handle, display_name
  into v_reactor
  from public.profiles
  where id = new.user_id;

  v_latest_handle := coalesce(v_reactor.handle, '@cofrade');

  v_payload := jsonb_build_object(
    'forumId', v_topic.forum_id,
    'topicId', v_topic.id,
    'replyId', v_reply.id::text,
    'profileId', new.user_id::text,
    'firstProfileId', new.user_id::text,
    'reaction', new.reaction,
    'lastReaction', new.reaction,
    'officialCategory', v_reply.official_category,
    'reactorCount', 1,
    'firstHandle', v_latest_handle
  );

  select id, payload
  into v_existing
  from public.notifications
  where user_id = v_reply.author_id
    and type = 'reply_reaction'
    and read_at is null
    and payload->>'replyId' = v_reply.id::text
  order by created_at desc
  limit 1;

  if found then
    v_count := coalesce((v_existing.payload->>'reactorCount')::int, 1) + 1;
    v_first_handle := coalesce(
      v_existing.payload->>'firstHandle',
      v_existing.title
    );

    v_subtitle := case v_count
      when 2 then
        v_first_handle || ' y ' || v_latest_handle || ' reaccionaron a tu comentario'
      else
        v_count::text || ' personas reaccionaron a tu comentario'
    end;

    v_payload := v_existing.payload || jsonb_build_object(
      'reactorCount', v_count,
      'profileId', new.user_id::text,
      'reaction', new.reaction,
      'lastReaction', new.reaction
    );

    update public.notifications
    set
      title = v_latest_handle,
      subtitle = v_subtitle,
      payload = v_payload,
      created_at = now()
    where id = v_existing.id;

    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  values (
    v_reply.author_id,
    'reply_reaction',
    v_latest_handle,
    new.reaction || ' · reaccionó a tu comentario',
    v_payload
  );

  return new;
end;
$$;

drop trigger if exists on_reply_reaction_notify on public.forum_reply_likes;
create trigger on_reply_reaction_notify
  after insert on public.forum_reply_likes
  for each row execute function public.notify_on_reply_reaction();

create or replace function public.reply_reaction_users(p_reply_id uuid)
returns table (
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  reaction text,
  reacted_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.user_id,
    p.handle,
    p.display_name,
    p.avatar_url,
    l.reaction,
    l.created_at as reacted_at
  from public.forum_reply_likes l
  join public.profiles p on p.id = l.user_id
  where l.reply_id = p_reply_id
  order by l.created_at desc;
$$;

grant execute on function public.reply_reaction_users(uuid) to authenticated, anon;


-- ###########################################################################
-- FILE: reply_reactions_mobile_fix.sql
-- ###########################################################################

-- Cofradero · reaction EXISTE pero el móvil falla al guardar (42703)
-- Causa típica: trigger de notificación busca notify_reactions (u otra col) y tumba el INSERT.
-- Ejecutar entero en SQL Editor del proyecto de env.json.

alter table public.notification_preferences
  add column if not exists notify_reactions boolean not null default true;

alter table public.notification_preferences
  add column if not exists notify_calendar boolean not null default true;

alter table public.notification_preferences
  add column if not exists notify_quiz boolean not null default true;

-- Preferencias: no fallar si falta alguna columna
create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_val boolean;
begin
  if p_pref = 'hashtags' then
    select coalesce(notify_hashtags, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'profiles' then
    select coalesce(notify_profiles, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'topics' then
    select coalesce(notify_topics, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'mentions' then
    select coalesce(notify_mentions, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'followers' then
    select coalesce(notify_followers, false) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'reactions' then
    select coalesce(notify_reactions, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'calendar' then
    select coalesce(notify_calendar, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  elsif p_pref = 'quiz' then
    select coalesce(notify_quiz, true) into v_val
    from public.notification_preferences where user_id = p_user_id;
  else
    return true;
  end if;

  if v_val is null then
    return p_pref <> 'followers';
  end if;
  return v_val;
exception
  when undefined_column then
    return p_pref <> 'followers';
  when others then
    return p_pref <> 'followers';
end;
$$;

-- Aviso de reacción: NUNCA debe impedir el upsert
create or replace function public.notify_on_reply_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply record;
  v_topic record;
  v_reactor record;
  v_existing record;
  v_latest_handle text;
  v_first_handle text;
  v_count int;
  v_subtitle text;
  v_payload jsonb;
begin
  begin
    perform set_config('row_security', 'off', true);

    select id, topic_id, author_id, official_category
    into v_reply
    from public.forum_replies
    where id = new.reply_id;

    if not found or v_reply.author_id is null then
      return new;
    end if;

    if v_reply.author_id = new.user_id then
      return new;
    end if;

    if not public.is_not_blocked(v_reply.author_id, new.user_id) then
      return new;
    end if;

    if not public.notify_pref_enabled(v_reply.author_id, 'reactions') then
      return new;
    end if;

    select id, forum_id, title
    into v_topic
    from public.forum_topics
    where id = v_reply.topic_id;

    if not found then
      return new;
    end if;

    select handle, display_name
    into v_reactor
    from public.profiles
    where id = new.user_id;

    v_latest_handle := coalesce(v_reactor.handle, '@cofrade');

    v_payload := jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', v_reply.id::text,
      'profileId', new.user_id::text,
      'firstProfileId', new.user_id::text,
      'reaction', new.reaction,
      'lastReaction', new.reaction,
      'officialCategory', v_reply.official_category,
      'reactorCount', 1,
      'firstHandle', v_latest_handle
    );

    select id, payload, title
    into v_existing
    from public.notifications
    where user_id = v_reply.author_id
      and type = 'reply_reaction'
      and read_at is null
      and payload->>'replyId' = v_reply.id::text
    order by created_at desc
    limit 1;

    if found then
      v_count := coalesce((v_existing.payload->>'reactorCount')::int, 1) + 1;
      v_first_handle := coalesce(
        v_existing.payload->>'firstHandle',
        v_existing.title
      );

      v_subtitle := case v_count
        when 2 then
          v_first_handle || ' y ' || v_latest_handle || ' reaccionaron a tu comentario'
        else
          v_count::text || ' personas reaccionaron a tu comentario'
      end;

      v_payload := v_existing.payload || jsonb_build_object(
        'reactorCount', v_count,
        'profileId', new.user_id::text,
        'reaction', new.reaction,
        'lastReaction', new.reaction
      );

      update public.notifications
      set
        title = v_latest_handle,
        subtitle = v_subtitle,
        payload = v_payload,
        created_at = now()
      where id = v_existing.id;
    else
      insert into public.notifications (user_id, type, title, subtitle, payload)
      values (
        v_reply.author_id,
        'reply_reaction',
        v_latest_handle,
        new.reaction || ' · reaccionó a tu comentario',
        v_payload
      );
    end if;
  exception
    when others then
      raise warning 'notify_on_reply_reaction: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists on_reply_reaction_notify on public.forum_reply_likes;
create trigger on_reply_reaction_notify
  after insert on public.forum_reply_likes
  for each row execute function public.notify_on_reply_reaction();

notify pgrst, 'reload schema';


-- ###########################################################################
-- FILE: topic_views_dedup.sql
-- ###########################################################################

-- Cofradero · visitas deduplicadas (1 por viewer y día)
-- Ejecutar en SQL Editor (sustituye la función anterior de topic_view_counter.sql)

create table if not exists public.topic_views (
  topic_id text not null references public.forum_topics (id) on delete cascade,
  viewer_id text not null,
  viewed_on date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (topic_id, viewer_id, viewed_on)
);

create index if not exists topic_views_topic_id_idx
  on public.topic_views (topic_id);

alter table public.topic_views enable row level security;

-- Solo la función RPC escribe; los clientes no leen esta tabla directamente.
drop policy if exists "Sin lectura directa de visitas" on public.topic_views;
create policy "Sin lectura directa de visitas"
  on public.topic_views for select using (false);

drop function if exists public.increment_topic_view(text);

create or replace function public.increment_topic_view(
  p_topic_id text,
  p_viewer_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int;
begin
  insert into public.topic_views (topic_id, viewer_id, viewed_on)
  values (p_topic_id, p_viewer_id, current_date)
  on conflict (topic_id, viewer_id, viewed_on) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.forum_topics
    set view_count = view_count + 1
    where id = p_topic_id;
  end if;
end;
$$;

grant execute on function public.increment_topic_view(text, text) to anon, authenticated;


-- ###########################################################################
-- FILE: sync_topic_comment_counts.sql
-- ###########################################################################

-- Cofradero · sincronizar comment_count con respuestas reales
-- Ejecutar en SQL Editor (una vez; también deja triggers de mantenimiento)

-- 1) Recalcular todos los contadores desde forum_replies
update public.forum_topics t
set comment_count = coalesce((
  select count(*)::int
  from public.forum_replies r
  where r.topic_id = t.id
), 0);

-- 2) Al borrar una respuesta, restar 1
create or replace function public.handle_forum_reply_deleted()
returns trigger
language plpgsql
security definer
set search_path = public
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

-- 3) Función para re-sincronizar manualmente si hiciera falta
create or replace function public.sync_all_topic_comment_counts()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.forum_topics t
  set comment_count = coalesce((
    select count(*)::int
    from public.forum_replies r
    where r.topic_id = t.id
  ), 0);
end;
$$;

grant execute on function public.sync_all_topic_comment_counts() to authenticated;


-- ###########################################################################
-- FILE: topic_moderation.sql
-- ###########################################################################

-- Cofradero · aprobación de temas por la Junta (Fase 8g)
-- Ejecutar en SQL Editor

alter table public.forum_topics
  add column if not exists status text not null default 'published'
  check (status in ('pending', 'published', 'rejected'));

-- Temas del seed y existentes siguen publicados
update public.forum_topics
set status = 'published'
where status is null or status = 'published';

-- Nuevos temas: pendientes hasta que la Junta apruebe
alter table public.forum_topics
  alter column status set default 'pending';

drop policy if exists "Temas legibles por todos" on public.forum_topics;
drop policy if exists "Temas publicados o propios" on public.forum_topics;

create policy "Temas publicados o propios"
  on public.forum_topics for select
  using (
    status = 'published'
    or author_id = auth.uid()
  );

-- Admin: en Table Editor cambia status a 'published' o 'rejected'


-- ###########################################################################
-- FILE: admin_roles.sql
-- ###########################################################################

-- Cofradero · roles de staff (Fase A)
-- Ejecutar en SQL Editor después de schema.sql

alter table public.profiles
  add column if not exists role text not null default 'member'
  check (role in ('member', 'editor', 'moderator', 'admin'));

-- Asignar tu cuenta admin (ajusta el handle):
-- update public.profiles set role = 'admin' where handle = 'jcaro';

create or replace function public.is_staff_user(p_user_id uuid)
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
      and role in ('admin', 'moderator')
  );
$$;

-- Solo bloquea que el usuario cambie SU PROPIO rol desde la app.
-- SQL Editor / Table Editor (auth.uid() null) y service role pueden asignar roles.
create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and auth.uid() = old.id then
    raise exception 'No puedes cambiar tu propio rol desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_role_guard on public.profiles;
create trigger on_profile_role_guard
  before update on public.profiles
  for each row execute function public.prevent_profile_role_change();

-- Temas: staff ve pendientes ajenos + puede moderar
drop policy if exists "Temas publicados o propios" on public.forum_topics;

drop policy if exists "Temas visibles según rol" on public.forum_topics;
create policy "Temas visibles según rol"
  on public.forum_topics for select
  using (
    status = 'published'
    or author_id = auth.uid()
    or public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff modera temas" on public.forum_topics;
create policy "Staff modera temas"
  on public.forum_topics for update
  using (public.is_staff_user(auth.uid()))
  with check (public.is_staff_user(auth.uid()));

-- Reportes: staff lee y resuelve
drop policy if exists "Staff lee reportes" on public.reports;
create policy "Staff lee reportes"
  on public.reports for select
  using (public.is_staff_user(auth.uid()));

drop policy if exists "Staff actualiza reportes" on public.reports;
create policy "Staff actualiza reportes"
  on public.reports for update
  using (public.is_staff_user(auth.uid()))
  with check (public.is_staff_user(auth.uid()));


-- ###########################################################################
-- FILE: admin_roles_fix_trigger.sql
-- ###########################################################################

-- Cofradero · corrección trigger roles
-- Ejecutar si no te deja cambiar role en Table Editor / SQL Editor

create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and auth.uid() = old.id then
    raise exception 'No puedes cambiar tu propio rol desde la app';
  end if;
  return new;
end;
$$;

-- Asignar admin (ajusta el handle):
-- update public.profiles set role = 'admin' where handle = 'jcaro';


-- ###########################################################################
-- FILE: profile_verification.sql
-- ###########################################################################

-- Cofradero · cuentas verificadas
-- Ejecutar después de schema.sql y admin_roles.sql.

alter table public.profiles
  add column if not exists verified boolean not null default false;

create or replace function public.is_admin_user(p_user_id uuid)
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
      and role = 'admin'
      and suspended_at is null
  );
$$;

-- Evita que una cuenta se marque a sí misma como verificada desde la app.
-- SQL Editor / Table Editor (auth.uid() null) y service role pueden gestionarlo.
create or replace function public.prevent_profile_verified_self_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.verified is distinct from old.verified
     and auth.uid() is not null
     and auth.uid() = old.id
     and not public.is_admin_user(auth.uid()) then
    raise exception 'No puedes cambiar tu propia verificación desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_verified_guard on public.profiles;
create trigger on_profile_verified_guard
  before update on public.profiles
  for each row execute function public.prevent_profile_verified_self_change();

drop policy if exists "Admin actualiza verificaciones de perfiles"
  on public.profiles;

create policy "Admin actualiza verificaciones de perfiles"
  on public.profiles for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Ejemplos:
-- update public.profiles set verified = true where handle = 'hermandad_sevilla';
-- update public.profiles set verified = false where handle = 'hermandad_sevilla';


-- ###########################################################################
-- FILE: notify_admins_moderation.sql
-- ###########################################################################

-- Cofradero · notificaciones a la Junta (Fase B)
-- Ejecutar después de admin_roles.sql + topic_moderation.sql

-- Nuevo tema pendiente → avisar a admin/moderator
create or replace function public.notify_admins_pending_topic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    p.id,
    'topic_pending_review',
    'Nuevo tema pendiente',
    new.author_handle || ' · ' || left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id,
      'authorId', new.author_id
    )
  from public.profiles p
  where p.role in ('admin', 'moderator')
    and p.id is distinct from new.author_id;

  return new;
end;
$$;

drop trigger if exists on_pending_topic_notify_admins on public.forum_topics;
create trigger on_pending_topic_notify_admins
  after insert on public.forum_topics
  for each row execute function public.notify_admins_pending_topic();

-- Cambio de estado → avisar al autor
create or replace function public.notify_author_topic_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = new.status then
    return new;
  end if;

  if new.author_id is null then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  if new.status = 'published' then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      new.author_id,
      'topic_published',
      'Tema publicado',
      'La Junta ha aprobado: ' || left(new.title, 80),
      jsonb_build_object('forumId', new.forum_id, 'topicId', new.id)
    );
  elsif new.status = 'rejected' then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      new.author_id,
      'topic_rejected',
      'Tema no publicado',
      'La Junta no ha publicado: ' || left(new.title, 80),
      jsonb_build_object('forumId', new.forum_id, 'topicId', new.id)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists on_topic_status_notify_author on public.forum_topics;
create trigger on_topic_status_notify_author
  after update of status on public.forum_topics
  for each row execute function public.notify_author_topic_status();

-- Nuevo reporte → avisar a la Junta
create or replace function public.notify_admins_new_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('row_security', 'off', true);

  -- Solo notificar la primera vez que un objetivo entra en cola pendiente.
  -- Si 50 usuarios reportan al mismo perfil, la Junta ve 1 aviso + el grupo en la app.
  if (
    select count(*)::int
    from public.reports r
    where r.target_type = new.target_type
      and r.target_id = new.target_id
      and r.status = 'pending'
  ) > 1 then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    p.id,
    'new_report',
    'Nuevo reporte',
    new.reason || ' · ' || new.target_type,
    jsonb_build_object(
      'reportId', new.id::text,
      'targetType', new.target_type,
      'targetId', new.target_id,
      'route', '/perfil/junta'
    )
  from public.profiles p
  where p.role in ('admin', 'moderator')
    and p.id is distinct from new.reporter_id;

  return new;
end;
$$;

drop trigger if exists on_new_report_notify_admins on public.reports;
create trigger on_new_report_notify_admins
  after insert on public.reports
  for each row execute function public.notify_admins_new_report();


-- ###########################################################################
-- FILE: topic_rejection_reason.sql
-- ###########################################################################

-- Cofradero · motivo de rechazo de temas (Junta → autor)
-- Ejecutar después de topic_moderation.sql y notify_admins_moderation.sql

alter table public.forum_topics
  add column if not exists rejection_reason text;

alter table public.forum_topics
  add column if not exists rejected_at timestamptz;

alter table public.forum_topics
  drop constraint if exists forum_topics_rejection_reason_len;

alter table public.forum_topics
  add constraint forum_topics_rejection_reason_len
  check (
    rejection_reason is null
    or char_length(btrim(rejection_reason)) between 3 and 280
  );

-- Historial: ordenar por fecha de rechazo (relleno para filas antiguas)
update public.forum_topics
set rejected_at = created_at
where status = 'rejected'
  and rejected_at is null;

create index if not exists forum_topics_rejected_at_idx
  on public.forum_topics (rejected_at desc nulls last)
  where status = 'rejected';

-- Cambio de estado → avisar al autor (con motivo si rechazan)
create or replace function public.notify_author_topic_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text;
begin
  if old.status = new.status then
    return new;
  end if;

  if new.author_id is null then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  if new.status = 'published' then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      new.author_id,
      'topic_published',
      'Tema publicado',
      'La Junta ha aprobado: ' || left(new.title, 80),
      jsonb_build_object('forumId', new.forum_id, 'topicId', new.id)
    );
  elsif new.status = 'rejected' then
    v_reason := nullif(btrim(coalesce(new.rejection_reason, '')), '');
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      new.author_id,
      'topic_rejected',
      'Tema no publicado',
      coalesce(
        left(v_reason, 120),
        'La Junta no ha publicado: ' || left(new.title, 80)
      ),
      jsonb_build_object(
        'forumId', new.forum_id,
        'topicId', new.id,
        'topicTitle', left(new.title, 120),
        'rejectionReason', v_reason
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists on_topic_status_notify_author on public.forum_topics;
create trigger on_topic_status_notify_author
  after update of status on public.forum_topics
  for each row execute function public.notify_author_topic_status();


-- ###########################################################################
-- FILE: topic_follows.sql
-- ###########################################################################

-- Cofradero · seguir hilos de foro (Fase 1)
-- Ejecutar en SQL Editor después de schema.sql + notifications_triggers.sql

-- Ampliar follows para hilos
alter table public.follows drop constraint if exists follows_target_type_check;
alter table public.follows add constraint follows_target_type_check
  check (target_type in ('hashtag', 'profile', 'topic'));

-- Notificar a seguidores del hilo cuando hay nueva respuesta
create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_topic_text := lower(
    regexp_replace(
      coalesce(v_topic.title, '') || ' ' ||
      coalesce(v_topic.excerpt, '') || ' ' ||
      coalesce(v_topic.body, ''),
      '[\s#]+',
      '',
      'g'
    )
  );

  -- Avisar al autor del tema (si tiene cuenta y no es el mismo que responde)
  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
    );
  end if;

  -- Avisar a quienes siguen un hashtag que aparece en el tema
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  -- Avisar a quienes siguen el hilo (el autor ya recibe user_reply)
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object('forumId', v_topic.forum_id, 'topicId', v_topic.id)
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: sync_forum_pillar_stats.sql
-- ###########################################################################

-- Cofradero · contadores reales de pilares de foro + última actividad
-- Ejecutar en SQL Editor (una vez; mantiene los datos con triggers)

alter table public.forum_pillars
  add column if not exists last_activity_at timestamptz;

alter table public.forum_pillars
  add column if not exists last_topic_id text references public.forum_topics (id) on delete set null;

alter table public.forum_pillars
  add column if not exists last_topic_title text;

create or replace function public.refresh_forum_pillar_stats(p_forum_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic_count int;
  v_reply_count int;
  v_last_topic_id text;
  v_last_topic_title text;
  v_last_activity timestamptz;
begin
  select count(*)::int
  into v_topic_count
  from public.forum_topics
  where forum_id = p_forum_id
    and status = 'published';

  select count(*)::int
  into v_reply_count
  from public.forum_replies r
  join public.forum_topics t on t.id = r.topic_id
  where t.forum_id = p_forum_id
    and t.status = 'published';

  select ta.topic_id, ta.title, ta.activity_at
  into v_last_topic_id, v_last_topic_title, v_last_activity
  from (
    select
      t.id as topic_id,
      t.title,
      greatest(
        t.created_at,
        coalesce((
          select max(r.created_at)
          from public.forum_replies r
          where r.topic_id = t.id
        ), t.created_at)
      ) as activity_at
    from public.forum_topics t
    where t.forum_id = p_forum_id
      and t.status = 'published'
  ) ta
  order by ta.activity_at desc
  limit 1;

  update public.forum_pillars
  set
    topic_count = coalesce(v_topic_count, 0),
    message_count = coalesce(v_reply_count, 0),
    last_activity_at = v_last_activity,
    last_topic_id = v_last_topic_id,
    last_topic_title = v_last_topic_title
  where id = p_forum_id;
end;
$$;

create or replace function public.refresh_forum_pillar_stats_from_topic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_forum_id text;
begin
  v_forum_id := coalesce(new.forum_id, old.forum_id);
  perform public.refresh_forum_pillar_stats(v_forum_id);
  return coalesce(new, old);
end;
$$;

create or replace function public.refresh_forum_pillar_stats_from_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_forum_id text;
begin
  select forum_id into v_forum_id
  from public.forum_topics
  where id = coalesce(new.topic_id, old.topic_id);

  if v_forum_id is not null then
    perform public.refresh_forum_pillar_stats(v_forum_id);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists on_forum_topic_stats on public.forum_topics;
create trigger on_forum_topic_stats
  after insert or update of status or delete on public.forum_topics
  for each row execute function public.refresh_forum_pillar_stats_from_topic();

drop trigger if exists on_forum_reply_stats on public.forum_replies;
create trigger on_forum_reply_stats
  after insert or delete on public.forum_replies
  for each row execute function public.refresh_forum_pillar_stats_from_reply();

-- Recalcular todos los pilares
do $$
declare
  r record;
begin
  for r in select id from public.forum_pillars loop
    perform public.refresh_forum_pillar_stats(r.id);
  end loop;
end;
$$;

grant execute on function public.refresh_forum_pillar_stats(text) to authenticated;


-- ###########################################################################
-- FILE: mention_notify_fix.sql
-- ###########################################################################

-- Arregla menciones @handle si el perfil guarda el handle con o sin @
-- Ejecutar en SQL Editor y vuelve a probar una mención.

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
  v_handle text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_topic_text := lower(
    regexp_replace(
      coalesce(v_topic.title, '') || ' ' ||
      coalesce(v_topic.excerpt, '') || ' ' ||
      coalesce(v_topic.body, ''),
      '[\s#]+',
      '',
      'g'
    )
  );

  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: mention_reply_scroll.sql
-- ###########################################################################

-- Cofradero · replyId en payload de notificaciones de respuesta
-- Ejecutar si ya corriste notification_social.sql antes de este cambio.
-- Permite scroll a la respuesta concreta al pulsar una mención o aviso de hilo.

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
  v_handle text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_topic_text := lower(
    regexp_replace(
      coalesce(v_topic.title, '') || ' ' ||
      coalesce(v_topic.excerpt, '') || ' ' ||
      coalesce(v_topic.body, ''),
      '[\s#]+',
      '',
      'g'
    )
  );

  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

-- Publicaciones oficiales hermandad → ver hermandad_official_post_notify.sql


-- ###########################################################################
-- FILE: hashtag_notify_fix.sql
-- ###########################################################################

-- Arregla notificaciones de hashtags que sigues:
-- 1) Nuevo tema publicado con ese #hashtag
-- 2) Respuesta que incluye el #hashtag (tema o comentario)
-- Ejecutar en SQL Editor después de notification_social.sql

-- ---------------------------------------------------------------------------
-- Tema nuevo publicado
-- ---------------------------------------------------------------------------
create or replace function public.notify_hashtag_followers_on_topic_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nueva conversación en ' || f.target_id,
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and (
      new.author_id is null
      or public.is_not_blocked(f.follower_id, new.author_id)
    )
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(new.title, '') || ' ' ||
        coalesce(new.excerpt, '') || ' ' ||
        coalesce(new.body, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  return new;
end;
$$;

drop trigger if exists on_topic_published_notify_hashtags on public.forum_topics;
create trigger on_topic_published_notify_hashtags
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_hashtag_followers_on_topic_published();

-- ---------------------------------------------------------------------------
-- Respuesta en foro (hashtags en tema + comentario)
-- ---------------------------------------------------------------------------
create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_handle text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(v_topic.title, '') || ' ' ||
        coalesce(v_topic.excerpt, '') || ' ' ||
        coalesce(v_topic.body, '') || ' ' ||
        coalesce(new.content, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: follows_see_followers.sql
-- ###########################################################################

-- Cofradero · permitir ver quién te sigue (follows → perfil)
-- Ejecutar en SQL Editor
--
-- Antes solo podías leer filas donde tú eres follower_id.
-- Ahora también puedes SELECT las que te tienen como target (profile).

drop policy if exists "Perfil ve sus seguidores" on public.follows;
create policy "Perfil ve sus seguidores"
  on public.follows for select
  using (
    target_type = 'profile'
    and target_id = auth.uid()::text
  );


-- ###########################################################################
-- FILE: admin_forum_pillars.sql
-- ###########################################################################

-- Cofradero · gestión de pilares de foro (solo admin)
-- Ejecutar en SQL Editor después de admin_roles.sql

create or replace function public.is_admin_user(p_user_id uuid)
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
      and role = 'admin'
  );
$$;

drop policy if exists "Admin actualiza pilares" on public.forum_pillars;
create policy "Admin actualiza pilares"
  on public.forum_pillars for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));


-- ###########################################################################
-- FILE: calendar_events.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: hermandad_official_posts.sql
-- ###########################################################################

-- Cofradero · publicaciones oficiales en tablones de hermandades
-- Ejecutar después de schema.sql, admin_roles.sql y profile_verification.sql.

alter table public.forum_replies
  add column if not exists is_official boolean not null default false;

alter table public.forum_replies
  add column if not exists official_category text;

alter table public.forum_replies
  drop constraint if exists forum_replies_official_category_check;

alter table public.forum_replies
  add constraint forum_replies_official_category_check
  check (
    official_category is null
    or official_category in (
      'noticia', 'culto', 'acto', 'patrimonio'
    )
  );

create or replace function public.prevent_manual_hermandad_topics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id = 'hermandades'
     and auth.uid() is not null then
    raise exception 'Hermandades es un directorio informativo: no admite temas nuevos desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_hermandad_topics_guard on public.forum_topics;
create trigger on_hermandad_topics_guard
  before insert on public.forum_topics
  for each row execute function public.prevent_manual_hermandad_topics();

create table if not exists public.hermandad_topic_accounts (
  topic_id text not null references public.forum_topics (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (topic_id, profile_id)
);

alter table public.hermandad_topic_accounts enable row level security;

drop policy if exists "Asignaciones hermandad legibles por staff" on public.hermandad_topic_accounts;
create policy "Asignaciones hermandad legibles por staff"
  on public.hermandad_topic_accounts for select
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'moderator')
        and p.suspended_at is null
    )
  );

drop policy if exists "Admin gestiona asignaciones hermandad" on public.hermandad_topic_accounts;
create policy "Admin gestiona asignaciones hermandad"
  on public.hermandad_topic_accounts for all
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
        and p.suspended_at is null
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
        and p.suspended_at is null
    )
  );

create or replace function public.can_create_official_hermandad_post(
  p_user_id uuid,
  p_topic_id text
)
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
      and suspended_at is null
      and role in ('admin', 'moderator')
  )
  or exists (
    select 1
    from public.profiles p
    join public.hermandad_topic_accounts a on a.profile_id = p.id
    where p.id = p_user_id
      and a.topic_id = p_topic_id
      and p.verified = true
      and p.suspended_at is null
  );
$$;

create or replace function public.prevent_invalid_official_hermandad_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_forum_id text;
begin
  select forum_id
  into v_forum_id
  from public.forum_topics
  where id = new.topic_id;

  if v_forum_id = 'hermandades' and coalesce(new.is_official, false) = false then
    raise exception 'Hermandades es un espacio informativo: solo admite publicaciones oficiales';
  end if;

  if coalesce(new.is_official, false) = false then
    new.official_category := null;
    return new;
  end if;

  if v_forum_id is distinct from 'hermandades' then
    raise exception 'Las publicaciones oficiales solo están disponibles en Hermandades';
  end if;

  if new.official_category is null then
    new.official_category := 'noticia';
  end if;

  if not public.can_create_official_hermandad_post(new.author_id, new.topic_id) then
    raise exception 'Solo la cuenta verificada asignada a esta hermandad o staff puede publicar información oficial';
  end if;

  return new;
end;
$$;

drop trigger if exists on_official_hermandad_post_guard on public.forum_replies;
create trigger on_official_hermandad_post_guard
  before insert or update of is_official, official_category, topic_id, author_id
  on public.forum_replies
  for each row execute function public.prevent_invalid_official_hermandad_post();

-- Ejemplo de asociación cuenta oficial -> tablón de hermandad:
-- insert into public.hermandad_topic_accounts (topic_id, profile_id)
-- select 'lunes-santo-san-pablo', id
-- from public.profiles
-- where handle = 'hdad_sanpablo';


-- ###########################################################################
-- FILE: roles_v2.sql
-- ###########################################################################

-- Cofradero · Roles v2 (permisos por contexto)
-- Ejecutar después de schema.sql, admin_roles.sql, calendar_events.sql,
-- hermandad_official_posts.sql y topic_moderation.sql. Idempotente.

-- ---------------------------------------------------------------------------
-- 1) Rol base: solo member | admin
-- ---------------------------------------------------------------------------
update public.profiles
set role = 'member', updated_at = now()
where role in ('editor', 'moderator');

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('member', 'admin'));

-- ---------------------------------------------------------------------------
-- 2) Tablas y columnas nuevas (sin políticas que dependan de funciones nuevas)
-- ---------------------------------------------------------------------------
create table if not exists public.forum_moderators (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  forum_id text not null references public.forum_pillars (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null,
  assigned_at timestamptz not null default now(),
  primary key (profile_id, forum_id)
);

create index if not exists forum_moderators_forum_idx
  on public.forum_moderators (forum_id);

alter table public.forum_moderators enable row level security;

create table if not exists public.forum_bans (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  forum_id text not null references public.forum_pillars (id) on delete cascade,
  banned_by uuid references public.profiles (id) on delete set null,
  reason text not null default '' check (char_length(reason) <= 500),
  banned_until timestamptz,
  created_at timestamptz not null default now(),
  unique (profile_id, forum_id)
);

create index if not exists forum_bans_forum_idx
  on public.forum_bans (forum_id);

alter table public.forum_bans enable row level security;

alter table public.forum_topics
  add column if not exists close_status text not null default 'open';

alter table public.forum_topics
  drop constraint if exists forum_topics_close_status_check;

alter table public.forum_topics
  add constraint forum_topics_close_status_check
  check (close_status in ('open', 'close_requested', 'closed'));

alter table public.forum_topics
  add column if not exists is_closed boolean not null default false;

alter table public.forum_topics
  add column if not exists edited_at timestamptz;

alter table public.forum_replies
  add column if not exists is_featured boolean not null default false;

alter table public.calendar_events
  add column if not exists status text not null default 'published';

alter table public.calendar_events
  drop constraint if exists calendar_events_status_check;

alter table public.calendar_events
  add constraint calendar_events_status_check
  check (status in ('published', 'pending_review', 'rejected'));

-- ---------------------------------------------------------------------------
-- 3) Funciones de permisos (ANTES de políticas RLS que las usan)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin_user(p_user_id uuid)
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
      and role = 'admin'
      and suspended_at is null
  );
$$;

create or replace function public.is_forum_moderator(
  p_user_id uuid,
  p_forum_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin_user(p_user_id)
  or exists (
    select 1
    from public.forum_moderators fm
    join public.profiles p on p.id = fm.profile_id
    where fm.profile_id = p_user_id
      and fm.forum_id = p_forum_id
      and p.suspended_at is null
  );
$$;

create or replace function public.is_junta_member(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin_user(p_user_id)
  or exists (
    select 1
    from public.forum_moderators fm
    join public.profiles p on p.id = fm.profile_id
    where fm.profile_id = p_user_id
      and p.suspended_at is null
  );
$$;

create or replace function public.can_submit_calendar_events(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_junta_member(p_user_id);
$$;

create or replace function public.is_calendar_editor(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_submit_calendar_events(p_user_id);
$$;

create or replace function public.is_staff_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_junta_member(p_user_id);
$$;

create or replace function public.is_topic_owner(p_user_id uuid, p_topic_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.forum_topics t
    join public.profiles p on p.id = p_user_id
    where t.id = p_topic_id
      and t.author_id = p_user_id
      and p.suspended_at is null
  );
$$;

create or replace function public.can_moderate_topic(
  p_user_id uuid,
  p_topic_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.forum_topics t
    where t.id = p_topic_id
      and public.is_forum_moderator(p_user_id, t.forum_id)
  );
$$;

create or replace function public.is_forum_banned(
  p_user_id uuid,
  p_forum_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.forum_bans b
    where b.profile_id = p_user_id
      and b.forum_id = p_forum_id
      and (b.banned_until is null or b.banned_until > now())
  );
$$;

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
        public.is_admin_user(p_user_id)
        or (
          e.created_by = p_user_id
          and e.status in ('published', 'pending_review', 'rejected')
        )
      )
  );
$$;

create or replace function public.can_create_official_hermandad_post(
  p_user_id uuid,
  p_topic_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin_user(p_user_id)
  or exists (
    select 1
    from public.profiles p
    join public.hermandad_topic_accounts a on a.profile_id = p.id
    where p.id = p_user_id
      and a.topic_id = p_topic_id
      and p.verified = true
      and p.suspended_at is null
  );
$$;

-- ---------------------------------------------------------------------------
-- 4) Políticas RLS
-- ---------------------------------------------------------------------------

-- forum_moderators
drop policy if exists "Moderadores legibles por junta" on public.forum_moderators;
create policy "Moderadores legibles por junta"
  on public.forum_moderators for select
  using (
    public.is_admin_user(auth.uid())
    or profile_id = auth.uid()
  );

drop policy if exists "Admin asigna moderadores" on public.forum_moderators;
create policy "Admin asigna moderadores"
  on public.forum_moderators for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Lectura del foro (ficha «Acerca del foro»): lectura pública de asignaciones.
drop policy if exists "Moderadores visibles publicamente" on public.forum_moderators;
create policy "Moderadores visibles publicamente"
  on public.forum_moderators for select
  using (true);

-- forum_bans
drop policy if exists "Usuario ve su ban de foro" on public.forum_bans;
create policy "Usuario ve su ban de foro"
  on public.forum_bans for select
  using (
    profile_id = auth.uid()
    or public.is_admin_user(auth.uid())
    or public.is_forum_moderator(auth.uid(), forum_id)
  );

drop policy if exists "Mod foro gestiona bans" on public.forum_bans;
create policy "Mod foro gestiona bans"
  on public.forum_bans for insert
  with check (
    public.is_admin_user(auth.uid())
    or public.is_forum_moderator(auth.uid(), forum_id)
  );

drop policy if exists "Mod foro actualiza bans" on public.forum_bans;
create policy "Mod foro actualiza bans"
  on public.forum_bans for update
  using (
    public.is_admin_user(auth.uid())
    or public.is_forum_moderator(auth.uid(), forum_id)
  )
  with check (
    public.is_admin_user(auth.uid())
    or public.is_forum_moderator(auth.uid(), forum_id)
  );

drop policy if exists "Mod foro elimina bans" on public.forum_bans;
create policy "Mod foro elimina bans"
  on public.forum_bans for delete
  using (
    public.is_admin_user(auth.uid())
    or public.is_forum_moderator(auth.uid(), forum_id)
  );

-- forum_topics
drop policy if exists "Temas visibles según rol" on public.forum_topics;
create policy "Temas visibles según rol"
  on public.forum_topics for select
  using (
    status = 'published'
    or author_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Staff modera temas" on public.forum_topics;
drop policy if exists "Titular edita su tema" on public.forum_topics;
drop policy if exists "Mod foro gestiona temas" on public.forum_topics;

create policy "Titular edita su tema"
  on public.forum_topics for update
  using (public.is_topic_owner(auth.uid(), id))
  with check (public.is_topic_owner(auth.uid(), id));

drop policy if exists "Mod foro gestiona temas" on public.forum_topics;
create policy "Mod foro gestiona temas"
  on public.forum_topics for update
  using (public.can_moderate_topic(auth.uid(), id))
  with check (public.can_moderate_topic(auth.uid(), id));

-- calendar_events
drop policy if exists "Eventos legibles por todos" on public.calendar_events;
drop policy if exists "Eventos publicados legibles" on public.calendar_events;
create policy "Eventos publicados legibles"
  on public.calendar_events for select
  using (
    status = 'published'
    or created_by = auth.uid()
    or public.is_admin_user(auth.uid())
  );

drop policy if exists "Editor crea eventos" on public.calendar_events;
drop policy if exists "Junta crea eventos" on public.calendar_events;
create policy "Junta crea eventos"
  on public.calendar_events for insert
  with check (public.can_submit_calendar_events(auth.uid()));

drop policy if exists "Editor gestiona sus eventos" on public.calendar_events;
drop policy if exists "Gestiona eventos propios o admin" on public.calendar_events;
create policy "Gestiona eventos propios o admin"
  on public.calendar_events for update
  using (public.can_manage_calendar_event(auth.uid(), id))
  with check (public.can_manage_calendar_event(auth.uid(), id));

drop policy if exists "Editor borra sus eventos" on public.calendar_events;
drop policy if exists "Borra eventos propios o admin" on public.calendar_events;
create policy "Borra eventos propios o admin"
  on public.calendar_events for delete
  using (public.can_manage_calendar_event(auth.uid(), id));

-- organizer_logos (biblioteca de escudos; misma junta que el calendario)
drop policy if exists "Escudos de organizador legibles" on public.organizer_logos;
create policy "Escudos de organizador legibles"
  on public.organizer_logos for select
  using (true);

drop policy if exists "Editor guarda escudos de organizador" on public.organizer_logos;
drop policy if exists "Junta guarda escudos de organizador" on public.organizer_logos;
create policy "Junta guarda escudos de organizador"
  on public.organizer_logos for insert
  with check (public.can_submit_calendar_events(auth.uid()));

drop policy if exists "Editor actualiza escudos de organizador" on public.organizer_logos;
drop policy if exists "Junta actualiza escudos de organizador" on public.organizer_logos;
create policy "Junta actualiza escudos de organizador"
  on public.organizer_logos for update
  using (public.can_submit_calendar_events(auth.uid()))
  with check (public.can_submit_calendar_events(auth.uid()));

drop policy if exists "Editor elimina escudos de organizador" on public.organizer_logos;
drop policy if exists "Junta elimina escudos de organizador" on public.organizer_logos;
create policy "Junta elimina escudos de organizador"
  on public.organizer_logos for delete
  using (public.can_submit_calendar_events(auth.uid()));

-- Storage: iconos y portadas de eventos (junta, no solo rol admin)
drop policy if exists "Editor sube iconos de eventos" on storage.objects;
drop policy if exists "Junta sube iconos de eventos" on storage.objects;
create policy "Junta sube iconos de eventos"
  on storage.objects for insert
  with check (
    bucket_id = 'event-icons'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.can_submit_calendar_events(auth.uid())
  );

drop policy if exists "Editor actualiza iconos de eventos" on storage.objects;
drop policy if exists "Junta actualiza iconos de eventos" on storage.objects;
create policy "Junta actualiza iconos de eventos"
  on storage.objects for update
  using (
    bucket_id = 'event-icons'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.can_submit_calendar_events(auth.uid())
  );

drop policy if exists "Editor borra iconos de eventos" on storage.objects;
drop policy if exists "Junta borra iconos de eventos" on storage.objects;
create policy "Junta borra iconos de eventos"
  on storage.objects for delete
  using (
    bucket_id = 'event-icons'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.can_submit_calendar_events(auth.uid())
  );

drop policy if exists "Editor sube portadas de eventos" on storage.objects;
drop policy if exists "Junta sube portadas de eventos" on storage.objects;
create policy "Junta sube portadas de eventos"
  on storage.objects for insert
  with check (
    bucket_id = 'event-covers'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.can_submit_calendar_events(auth.uid())
  );

drop policy if exists "Editor actualiza portadas de eventos" on storage.objects;
drop policy if exists "Junta actualiza portadas de eventos" on storage.objects;
create policy "Junta actualiza portadas de eventos"
  on storage.objects for update
  using (
    bucket_id = 'event-covers'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.can_submit_calendar_events(auth.uid())
  );

drop policy if exists "Editor borra portadas de eventos" on storage.objects;
drop policy if exists "Junta borra portadas de eventos" on storage.objects;
create policy "Junta borra portadas de eventos"
  on storage.objects for delete
  using (
    bucket_id = 'event-covers'
    and auth.uid()::text = (storage.foldername(name))[1]
    and public.can_submit_calendar_events(auth.uid())
  );

-- reports
drop policy if exists "Staff lee reportes" on public.reports;
drop policy if exists "Staff actualiza reportes" on public.reports;
drop policy if exists "Junta lee reportes" on public.reports;
drop policy if exists "Junta actualiza reportes" on public.reports;

create policy "Junta lee reportes"
  on public.reports for select
  using (public.is_junta_member(auth.uid()));

drop policy if exists "Junta actualiza reportes" on public.reports;
create policy "Junta actualiza reportes"
  on public.reports for update
  using (public.is_junta_member(auth.uid()))
  with check (public.is_junta_member(auth.uid()));

-- hermandad_topic_accounts
drop policy if exists "Asignaciones hermandad legibles por staff" on public.hermandad_topic_accounts;
drop policy if exists "Asignaciones hermandad legibles por junta" on public.hermandad_topic_accounts;
create policy "Asignaciones hermandad legibles por junta"
  on public.hermandad_topic_accounts for select
  using (public.is_junta_member(auth.uid()) or profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5) Triggers
-- ---------------------------------------------------------------------------
create or replace function public.set_calendar_event_status_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin_user(new.created_by) then
    new.status := coalesce(nullif(new.status, ''), 'published');
  elsif public.can_submit_calendar_events(new.created_by) then
    new.status := 'pending_review';
  else
    raise exception 'No tienes permiso para crear eventos en el calendario';
  end if;
  return new;
end;
$$;

drop trigger if exists on_calendar_event_status on public.calendar_events;
create trigger on_calendar_event_status
  before insert on public.calendar_events
  for each row execute function public.set_calendar_event_status_on_insert();

create or replace function public.notify_admins_pending_topic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;

  for v_admin in
    select p.id
    from public.profiles p
    where p.role = 'admin'
      and p.suspended_at is null
  loop
    insert into public.notifications (
      user_id, type, title, subtitle, payload
    ) values (
      v_admin.id,
      'topic_pending_review',
      'Nuevo tema pendiente',
      '«' || left(new.title, 80) || '» espera revisión de la Junta.',
      jsonb_build_object(
        'forum_id', new.forum_id,
        'topic_id', new.id
      )
    );
  end loop;

  return new;
end;
$$;

create or replace function public.notify_admins_new_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
begin
  for v_admin in
    select p.id
    from public.profiles p
    where p.role = 'admin'
      and p.suspended_at is null
  loop
    insert into public.notifications (
      user_id, type, title, subtitle, payload
    ) values (
      v_admin.id,
      'new_report',
      'Nuevo reporte',
      'Hay un reporte de moderación pendiente.',
      jsonb_build_object(
        'report_id', new.id,
        'target_type', new.target_type,
        'target_id', new.target_id
      )
    );
  end loop;

  return new;
end;
$$;

create or replace function public.notify_admins_calendar_pending()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
begin
  if new.status is distinct from 'pending_review' then
    return new;
  end if;

  for v_admin in
    select p.id from public.profiles p
    where p.role = 'admin' and p.suspended_at is null
  loop
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_admin.id,
      'calendar_pending_review',
      'Evento pendiente',
      '«' || left(new.title, 80) || '» espera aprobación.',
      jsonb_build_object('event_id', new.id)
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists on_calendar_pending_notify on public.calendar_events;
create trigger on_calendar_pending_notify
  after insert on public.calendar_events
  for each row execute function public.notify_admins_calendar_pending();

create or replace function public.notify_admins_close_requested()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
begin
  if new.close_status is distinct from 'close_requested'
     or old.close_status = 'close_requested' then
    return new;
  end if;

  for v_admin in
    select p.id from public.profiles p
    where p.role = 'admin' and p.suspended_at is null
  loop
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_admin.id,
      'topic_close_requested',
      'Cierre de tema solicitado',
      '«' || left(new.title, 80) || '» — el titular pide cerrar el hilo.',
      jsonb_build_object('forum_id', new.forum_id, 'topic_id', new.id)
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists on_topic_close_requested_notify on public.forum_topics;
create trigger on_topic_close_requested_notify
  after update of close_status on public.forum_topics
  for each row execute function public.notify_admins_close_requested();


-- ###########################################################################
-- FILE: forum_moderators_public_read.sql
-- ###########################################################################

-- Cofradero · lectura pública de moderadores de foro
-- Necesario para la ficha «Acerca del foro». Idempotente.
-- Ejecutar si la lista de moderadores se queda cargando o vacía para usuarios normales.

drop policy if exists "Moderadores visibles publicamente" on public.forum_moderators;
create policy "Moderadores visibles publicamente"
  on public.forum_moderators for select
  using (true);


-- ###########################################################################
-- FILE: delete_rejected_topics.sql
-- ###########################################################################

-- Cofradero · borrar temas desde Junta (historial de rechazos + Moderar tema en foros)
-- Ejecutar después de topic_rejection_reason.sql y roles_v2.sql
-- Si ya ejecutaste la versión solo-rejected, vuelve a correr este script.

drop policy if exists "Junta borra temas rechazados" on public.forum_topics;
drop policy if exists "Junta borra temas" on public.forum_topics;
create policy "Junta borra temas"
  on public.forum_topics for delete
  using (public.can_moderate_topic(auth.uid(), id));


-- ###########################################################################
-- FILE: forum_pillar_covers.sql
-- ###########################################################################

-- Cofradero · portadas de foro + hero global de la pantalla FOROS
-- Ejecutar después de forum_pillar_icons.sql. Idempotente.

alter table public.forum_pillars
  add column if not exists cover_image_url text;

create table if not exists public.app_config (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

drop policy if exists "App config lectura publica" on public.app_config;
create policy "App config lectura publica"
  on public.app_config for select
  using (true);

drop policy if exists "Admin gestiona app config" on public.app_config;
create policy "Admin gestiona app config"
  on public.app_config for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

insert into public.app_config (key, value)
values ('forums_list_hero_image_url', '')
on conflict (key) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-covers',
  'forum-covers',
  true,
  5242880,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Portadas foro lectura publica" on storage.objects;
create policy "Portadas foro lectura publica"
  on storage.objects for select
  using (bucket_id = 'forum-covers');

drop policy if exists "Admin sube portadas foro" on storage.objects;
create policy "Admin sube portadas foro"
  on storage.objects for insert
  with check (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin actualiza portadas foro" on storage.objects;
create policy "Admin actualiza portadas foro"
  on storage.objects for update
  using (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  )
  with check (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin borra portadas foro" on storage.objects;
create policy "Admin borra portadas foro"
  on storage.objects for delete
  using (
    bucket_id = 'forum-covers'
    and public.is_admin_user(auth.uid())
  );


-- ###########################################################################
-- FILE: forum_pillar_icons.sql
-- ###########################################################################

-- Cofradero · iconos de foro (imagen + gestión admin)
-- Ejecutar después de admin_forum_pillars.sql. Idempotente.

alter table public.forum_pillars
  add column if not exists icon_image_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-icons',
  'forum-icons',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Iconos foro lectura publica" on storage.objects;
create policy "Iconos foro lectura publica"
  on storage.objects for select
  using (bucket_id = 'forum-icons');

drop policy if exists "Admin sube iconos foro" on storage.objects;
create policy "Admin sube iconos foro"
  on storage.objects for insert
  with check (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin actualiza iconos foro" on storage.objects;
create policy "Admin actualiza iconos foro"
  on storage.objects for update
  using (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  )
  with check (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin borra iconos foro" on storage.objects;
create policy "Admin borra iconos foro"
  on storage.objects for delete
  using (
    bucket_id = 'forum-icons'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin crea pilares" on public.forum_pillars;
create policy "Admin crea pilares"
  on public.forum_pillars for insert
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Admin borra pilares" on public.forum_pillars;
create policy "Admin borra pilares"
  on public.forum_pillars for delete
  using (public.is_admin_user(auth.uid()));


-- ###########################################################################
-- FILE: forum_pillar_about.sql
-- ###########################################################################

-- Cofradero · contenido «Acerca del foro» editable
-- Ejecutar después de forum_pillar_covers.sql. Idempotente.

alter table public.forum_pillars
  add column if not exists about_tagline text;

alter table public.forum_pillars
  add column if not exists about_body text;

alter table public.forum_pillars
  add column if not exists forum_rules text;

-- Los moderadores son visibles en la ficha pública del foro.
do $$
begin
  if to_regclass('public.forum_moderators') is null then
    return;
  end if;
  drop policy if exists "Moderadores visibles publicamente" on public.forum_moderators;
  create policy "Moderadores visibles publicamente"
    on public.forum_moderators for select
    using (true);
end $$;

-- Texto por defecto del apartado Hermandades (canal oficial, no foro).
update public.forum_pillars
set
  about_tagline = coalesce(
    nullif(trim(about_tagline), ''),
    'Noticias, cultos, actos y patrimonio de las hermandades de Sevilla.'
  ),
  about_body = coalesce(
    nullif(trim(about_body), ''),
    'Este apartado no es un foro de debate. Aquí cada hermandad publica de forma oficial sus noticias, cultos, actos y patrimonio a través de su cuenta verificada.' || E'\n\n' ||
    'Los cofrades pueden consultar y seguir la actualidad, pero no es posible abrir temas ni comentar: el contenido lo gestionan exclusivamente las cuentas verificadas de cada hermandad.'
  ),
  forum_rules = coalesce(
    nullif(trim(forum_rules), ''),
    'Solo las hermandades con cuenta verificada pueden publicar.' || E'\n' ||
    'No está permitido abrir temas ni comentar en este apartado.' || E'\n' ||
    'El contenido es informativo: noticias, cultos, actos y patrimonio.' || E'\n' ||
    'Cada publicación es responsabilidad de la hermandad que la emite.' || E'\n' ||
    'Para dudas concretas, contacta con la hermandad por sus canales oficiales.'
  )
where id = 'hermandades';


-- ###########################################################################
-- FILE: topic_icons.sql
-- ###########################################################################

-- Cofradero · iconos y portadas de temas destacados
-- Ejecutar después de pinned_topics.sql. Idempotente.

alter table public.forum_topics
  add column if not exists icon_key text;

alter table public.forum_topics
  add column if not exists cover_image_url text;

update public.forum_topics set icon_key = 'filter_vintage_outlined'
where id = 'circulo-cuaresma';

update public.forum_topics set icon_key = 'account_balance'
where id = 'circulo-semana-santa';

update public.forum_topics set icon_key = 'wb_sunny_outlined'
where id = 'circulo-glorias';

update public.forum_topics set icon_key = 'workspace_premium_outlined'
where id = 'martillo-cambio-capataces';


-- ###########################################################################
-- FILE: forum_topic_user_covers.sql
-- ###########################################################################

-- Cofradero · portadas de tema subidas por el titular del hilo
-- Ejecutar después de pinned_topics_admin.sql (bucket topic-covers).
-- Permite adjuntar un cartel/foto al crear (o editar) un tema propio.

alter table public.forum_topics
  add column if not exists cover_image_url text;

-- Titular (o staff) puede subir/actualizar/borrar portadas en topic-covers/{topic_id}/...
drop policy if exists "Titular o staff sube portadas temas" on storage.objects;
create policy "Titular o staff sube portadas temas"
  on storage.objects for insert
  with check (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  );

drop policy if exists "Titular o staff actualiza portadas temas" on storage.objects;
create policy "Titular o staff actualiza portadas temas"
  on storage.objects for update
  using (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  )
  with check (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  );

drop policy if exists "Titular o staff borra portadas temas" on storage.objects;
create policy "Titular o staff borra portadas temas"
  on storage.objects for delete
  using (
    bucket_id = 'topic-covers'
    and (
      public.is_staff_user(auth.uid())
      or public.is_topic_owner(
        auth.uid(),
        (storage.foldername(name))[1]
      )
    )
  );

-- Las políticas antiguas solo-staff quedan sustituidas por las de arriba.
drop policy if exists "Staff sube portadas temas" on storage.objects;
drop policy if exists "Staff actualiza portadas temas" on storage.objects;
drop policy if exists "Staff borra portadas temas" on storage.objects;


-- ###########################################################################
-- FILE: forum_topic_reactions.sql
-- ###########################################################################

-- Cofradero · reacciones en temas (mismo catálogo emoji que respuestas)
-- Ejecutar tras reply_reactions_emoji.sql.
-- Idempotente.

create table if not exists public.forum_topic_likes (
  topic_id text not null references public.forum_topics (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  reaction text not null default '❤️'
    check (char_length(reaction) >= 1 and char_length(reaction) <= 16),
  created_at timestamptz not null default now(),
  primary key (topic_id, user_id)
);

create index if not exists forum_topic_likes_topic_id_idx
  on public.forum_topic_likes (topic_id);

alter table public.forum_topic_likes enable row level security;

drop policy if exists "Reacciones tema legibles" on public.forum_topic_likes;
create policy "Reacciones tema legibles"
  on public.forum_topic_likes for select using (true);

drop policy if exists "Usuario reacciona a tema" on public.forum_topic_likes;
create policy "Usuario reacciona a tema"
  on public.forum_topic_likes for insert
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario cambia reacción tema" on public.forum_topic_likes;
create policy "Usuario cambia reacción tema"
  on public.forum_topic_likes for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario quita reacción tema" on public.forum_topic_likes;
create policy "Usuario quita reacción tema"
  on public.forum_topic_likes for delete
  using (auth.uid() = user_id);

create or replace function public.topic_reaction_counts(p_topic_id text)
returns table (reaction text, reaction_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select l.reaction, count(*)::bigint
  from public.forum_topic_likes l
  where l.topic_id = p_topic_id
  group by l.reaction;
$$;

grant execute on function public.topic_reaction_counts(text) to authenticated, anon;

create or replace function public.topic_reaction_users(p_topic_id text)
returns table (
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  reaction text,
  reacted_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.user_id,
    coalesce(p.handle, 'cofrade') as handle,
    coalesce(p.display_name, 'Cofrade') as display_name,
    p.avatar_url,
    l.reaction,
    l.created_at as reacted_at
  from public.forum_topic_likes l
  left join public.profiles p on p.id = l.user_id
  where l.topic_id = p_topic_id
  order by l.created_at desc;
$$;

grant execute on function public.topic_reaction_users(text) to authenticated, anon;

alter table public.forum_topic_likes replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.forum_topic_likes;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- FILE: calendar_notify.sql
-- ###########################################################################

-- Cofradero · avisos de calendario para usuarios finales
-- Ejecutar después de:
--   - schema.sql
--   - notification_social.sql
--   - calendar_events.sql
--   - roles_v2.sql (si usas estados published/pending_review/rejected)
--   - reply_reaction_notify.sql (o al menos la columna notify_reactions)

alter table public.notification_preferences
  add column if not exists notify_reactions boolean not null default true;

-- Amplía el helper de preferencias para soportar notify_calendar.
create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'calendar' then coalesce(
      (select notify_calendar from public.notification_preferences where user_id = p_user_id),
      false
    )
    else true
  end;
$$;

create or replace function public.notify_users_on_calendar_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
begin
  if new.status <> 'published' then
    return new;
  end if;

  -- Evita duplicar avisos si el evento ya estaba publicado.
  if tg_op = 'UPDATE' and coalesce(old.status, '') = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  v_title := case new.event_type
    when 'procesion' then 'Nueva procesión en el calendario'
    when 'gloria' then 'Nuevo acto de gloria'
    when 'ensayo' then 'Nuevo ensayo en el calendario'
    when 'iguala' then 'Nueva igualá en el calendario'
    when 'concierto' then 'Nuevo concierto cofrade'
    else 'Nuevo aviso del calendario'
  end;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    p.id,
    'calendar',
    v_title,
    left(new.title, 80),
    jsonb_build_object(
      'route', '/calendario',
      'eventId', new.id::text,
      'eventType', new.event_type,
      'startsAt', new.starts_at,
      'organizerLabel', new.organizer_label
    )
  from public.profiles p
  where p.suspended_at is null
    and p.id is distinct from new.created_by
    and public.notify_pref_enabled(p.id, 'calendar');

  return new;
end;
$$;

drop trigger if exists on_calendar_published_notify_users on public.calendar_events;
create trigger on_calendar_published_notify_users
  after insert or update of status on public.calendar_events
  for each row execute function public.notify_users_on_calendar_published();


-- ###########################################################################
-- FILE: calendar_event_reminders.sql
-- ###########################################################################

-- Cofradero · recordatorios de eventos del calendario (24 h y 1 h antes)
-- Ejecutar después de calendar_notify.sql y event_bookmarks.sql
--
-- Requiere extensión pg_cron (Supabase → Database → Extensions → pg_cron)

-- ---------------------------------------------------------------------------
-- Control de envíos (evita duplicados)
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_reminder_dispatches (
  user_id uuid not null references public.profiles (id) on delete cascade,
  event_id uuid not null references public.calendar_events (id) on delete cascade,
  reminder_kind text not null check (reminder_kind in ('24h', '1h')),
  sent_at timestamptz not null default now(),
  primary key (user_id, event_id, reminder_kind)
);

create index if not exists calendar_reminder_dispatches_event_idx
  on public.calendar_reminder_dispatches (event_id);

alter table public.calendar_reminder_dispatches enable row level security;

-- Solo uso interno (triggers/cron); la app no necesita leer esta tabla.
drop policy if exists "Sin acceso cliente a dispatches" on public.calendar_reminder_dispatches;
create policy "Sin acceso cliente a dispatches"
  on public.calendar_reminder_dispatches for all
  using (false)
  with check (false);

-- ---------------------------------------------------------------------------
-- Envía recordatorios pendientes
-- ---------------------------------------------------------------------------
create or replace function public.dispatch_calendar_event_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event record;
  v_kind text;
  v_title text;
  v_window_start interval;
  v_window_end interval;
  v_inserted integer := 0;
  v_batch integer;
begin
  perform set_config('row_security', 'off', true);

  foreach v_kind in array array['24h', '1h'] loop
    if v_kind = '24h' then
      v_window_start := interval '23 hours';
      v_window_end := interval '24 hours';
      v_title := 'Mañana en el calendario';
    else
      v_window_start := interval '55 minutes';
      v_window_end := interval '65 minutes';
      v_title := 'Empieza pronto';
    end if;

    for v_event in
      select
        e.id,
        e.title,
        e.event_type,
        e.starts_at,
        e.organizer_label
      from public.calendar_events e
      where coalesce(e.status, 'published') = 'published'
        and e.starts_at > now()
        and e.starts_at > now() + v_window_start
        and e.starts_at <= now() + v_window_end
    loop
      with recipients as (
        select p.id as user_id
        from public.profiles p
        where p.suspended_at is null
          and public.notify_pref_enabled(p.id, 'calendar')
          and not exists (
            select 1
            from public.calendar_reminder_dispatches d
            where d.user_id = p.id
              and d.event_id = v_event.id
              and d.reminder_kind = v_kind
          )
      ),
      inserted as (
        insert into public.notifications (user_id, type, title, subtitle, payload)
        select
          r.user_id,
          'calendar',
          v_title,
          left(v_event.title, 80),
          jsonb_build_object(
            'route', '/calendario',
            'eventId', v_event.id::text,
            'eventType', v_event.event_type,
            'startsAt', v_event.starts_at,
            'organizerLabel', v_event.organizer_label,
            'reminderKind', v_kind
          )
        from recipients r
        returning user_id
      ),
      logged as (
        insert into public.calendar_reminder_dispatches (
          user_id, event_id, reminder_kind
        )
        select user_id, v_event.id, v_kind
        from inserted
        returning 1
      )
      select count(*)::integer into v_batch from logged;

      v_inserted := v_inserted + coalesce(v_batch, 0);
    end loop;
  end loop;

  return v_inserted;
end;
$$;

-- ---------------------------------------------------------------------------
-- pg_cron: ejecutar cada 15 minutos
-- ---------------------------------------------------------------------------
-- Descomenta tras activar la extensión pg_cron en el dashboard:
--
-- create extension if not exists pg_cron with schema extensions;
--
-- select cron.unschedule('dispatch-calendar-event-reminders')
-- where exists (
--   select 1 from cron.job where jobname = 'dispatch-calendar-event-reminders'
-- );
--
-- select cron.schedule(
--   'dispatch-calendar-event-reminders',
--   '*/15 * * * *',
--   $$ select public.dispatch_calendar_event_reminders(); $$
-- );
--
-- Prueba manual:
-- select public.dispatch_calendar_event_reminders();


-- ###########################################################################
-- FILE: calendar_event_moderator_manage_fix.sql
-- ###########################################################################

-- Cofradero · permite a moderadores editar/borrar sus propios eventos
-- Ejecutar si un moderador puede crear pero no editar (p. ej. tras re-ejecutar calendar_events.sql).

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
        public.is_admin_user(p_user_id)
        or (
          e.created_by = p_user_id
          and e.status in ('published', 'pending_review', 'rejected')
        )
      )
  );
$$;


-- ###########################################################################
-- FILE: event_bookmarks.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: event_live_updates.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: google_oauth_profile.sql
-- ###########################################################################

-- Cofradero · perfil al registrarse con Google (OAuth)
-- Ejecutar una vez en SQL Editor si ya tienes schema.sql desplegado.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  raw_handle text;
  display text;
  avatar text;
begin
  display := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    split_part(new.email, '@', 1)
  );
  display := left(display, 40);
  if char_length(display) < 2 then
    display := left(coalesce(nullif(split_part(new.email, '@', 1), ''), 'Cofrade'), 40);
  end if;

  avatar := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'picture'), '')
  );

  raw_handle := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'handle'), ''),
    split_part(new.email, '@', 1)
  );
  raw_handle := lower(regexp_replace(raw_handle, '[^a-z0-9_]', '', 'g'));
  if raw_handle = '' then
    raw_handle := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;
  if char_length(raw_handle) < 3 then
    raw_handle := raw_handle || '_' || substr(replace(new.id::text, '-', ''), 1, 4);
  end if;

  -- Evita choque si el handle ya existe (p. ej. dos cuentas gmail parecidas).
  while exists (select 1 from public.profiles where handle = raw_handle) loop
    raw_handle := raw_handle || '_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 4);
  end loop;

  insert into public.profiles (id, handle, display_name, avatar_url)
  values (new.id, raw_handle, display, avatar)
  on conflict (id) do nothing;

  return new;
end;
$$;


-- ###########################################################################
-- FILE: search_trends.sql
-- ###########################################################################

-- Cofradero · tendencias reales en Buscar (#hashtags)
-- Ejecutar en SQL Editor (no requiere tablas nuevas)

create or replace function public.fetch_trending_hashtags(p_limit integer default 8)
returns table (
  hashtag text,
  post_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with corpus as (
    select
      coalesce(title, '') || ' ' ||
      coalesce(excerpt, '') || ' ' ||
      coalesce(body, '') as text
    from public.forum_topics
    where status = 'published'
    union all
    select coalesce(r.content, '') as text
    from public.forum_replies r
    join public.forum_topics t on t.id = r.topic_id
    where t.status = 'published'
  ),
  tags as (
    select '#' || (m)[1] as tag
    from corpus,
    lateral regexp_matches(
      text,
      '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
      'g'
    ) as m
  )
  select (array_agg(tag order by tag))[1] as hashtag, count(*)::bigint as post_count
  from tags
  group by lower(tag)
  order by post_count desc, hashtag asc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.fetch_trending_hashtags(integer) to anon, authenticated;


-- ###########################################################################
-- FILE: forum_reply_edit_delete.sql
-- ###########################################################################

-- Cofradero · editar / ocultar respuestas (soft delete + auditoría)
-- Ejecutar en SQL Editor después de admin_roles.sql

alter table public.forum_replies
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles (id) on delete set null;

create index if not exists forum_replies_deleted_at_idx
  on public.forum_replies (deleted_at)
  where deleted_at is not null;

-- ---------------------------------------------------------------------------
-- Editar respuesta propia (30 min, sin respuestas hijas)
-- ---------------------------------------------------------------------------
create or replace function public.update_own_forum_reply(
  p_reply_id uuid,
  p_content text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
  v_child_count int;
  v_content text := trim(p_content);
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if v_reply.author_id is distinct from auth.uid() then
    raise exception 'forbidden';
  end if;

  if v_reply.deleted_at is not null then
    raise exception 'deleted';
  end if;

  if v_reply.created_at < now() - interval '30 minutes' then
    raise exception 'edit_window_expired';
  end if;

  select count(*)::int into v_child_count
  from public.forum_replies
  where parent_reply_id = p_reply_id
    and deleted_at is null;

  if v_child_count > 0 then
    raise exception 'has_replies';
  end if;

  if char_length(v_content) < 1 or char_length(v_content) > 4000 then
    raise exception 'invalid_content';
  end if;

  update public.forum_replies
  set content = v_content,
      edited_at = now()
  where id = p_reply_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Ocultar respuesta (soft delete): autor o Junta
-- El texto permanece en BD para moderación / reportes
-- ---------------------------------------------------------------------------
create or replace function public.soft_delete_forum_reply(p_reply_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if v_reply.deleted_at is not null then
    return;
  end if;

  if v_reply.author_id is distinct from auth.uid()
     and not public.is_staff_user(auth.uid()) then
    raise exception 'forbidden';
  end if;

  update public.forum_replies
  set deleted_at = now(),
      deleted_by = auth.uid()
  where id = p_reply_id;
end;
$$;

grant execute on function public.update_own_forum_reply(uuid, text) to authenticated;
grant execute on function public.soft_delete_forum_reply(uuid) to authenticated;


-- ###########################################################################
-- FILE: device_tokens.sql
-- ###########################################################################

-- Cofradero · tokens FCM por dispositivo (Fase 9a)
-- Ejecutar si ya tienes notification_social.sql (notification_preferences ya existe).
-- Ver docs/PUSH_FCM.md

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'web')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "Usuario gestiona sus tokens FCM" on public.device_tokens;
create policy "Usuario gestiona sus tokens FCM"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- ###########################################################################
-- FILE: device_tokens_unique.sql
-- ###########################################################################

-- Cofradero · un FCM token = un solo usuario (evita 3 pushes en el mismo móvil)
-- Ejecutar en SQL Editor.

-- 1) Limpiar duplicados: deja solo la fila más reciente por token
delete from public.device_tokens dt
where dt.id not in (
  select distinct on (fcm_token) id
  from public.device_tokens
  order by fcm_token, updated_at desc
);

-- 2) Unicidad global del token
alter table public.device_tokens
  drop constraint if exists device_tokens_user_id_fcm_token_key;

alter table public.device_tokens
  drop constraint if exists device_tokens_fcm_token_key;

alter table public.device_tokens
  add constraint device_tokens_fcm_token_key unique (fcm_token);

-- 3) RPC: al registrar, reclama el token (quita otras cuentas)
create or replace function public.claim_device_token(
  p_fcm_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if p_fcm_token is null or length(trim(p_fcm_token)) < 10 then
    raise exception 'Token inválido';
  end if;
  if p_platform not in ('ios', 'android', 'web') then
    raise exception 'Plataforma inválida';
  end if;

  delete from public.device_tokens
  where fcm_token = p_fcm_token
    and user_id <> v_uid;

  delete from public.device_tokens
  where user_id = v_uid
    and platform = p_platform
    and fcm_token <> p_fcm_token;

  insert into public.device_tokens (user_id, fcm_token, platform, updated_at)
  values (v_uid, p_fcm_token, p_platform, now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = excluded.updated_at;
end;
$$;

revoke all on function public.claim_device_token(text, text) from public;
grant execute on function public.claim_device_token(text, text) to authenticated;


-- ###########################################################################
-- FILE: notifications_push.sql
-- ###########################################################################

-- Cofradero · tablas para push FCM (Fase 9)
-- Ejecutar cuando implementes Firebase Cloud Messaging.
-- Ver docs/NOTIFICACIONES.md

-- Tokens FCM por dispositivo
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null,
  platform text not null check (platform in ('ios', 'android', 'web')),
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

alter table public.device_tokens enable row level security;

drop policy if exists "Usuario gestiona sus tokens FCM" on public.device_tokens;
create policy "Usuario gestiona sus tokens FCM"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Preferencias de notificación
create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  notify_hashtags boolean not null default true,
  notify_profiles boolean not null default true,
  notify_mentions boolean not null default true,
  notify_followers boolean not null default false,
  notify_topics boolean not null default true,
  notify_calendar boolean not null default false,
  push_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists "Usuario lee y edita sus preferencias" on public.notification_preferences;
create policy "Usuario lee y edita sus preferencias"
  on public.notification_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Crear preferencias por defecto al registrar perfil
create or replace function public.handle_new_profile_preferences()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created_preferences on public.profiles;
create trigger on_profile_created_preferences
  after insert on public.profiles
  for each row execute function public.handle_new_profile_preferences();


-- ###########################################################################
-- FILE: push_opt_in_default.sql
-- ###########################################################################

-- Push desactivado por defecto (opt-in). Ejecutar una vez en SQL Editor.
-- Usuarios que nunca registraron un dispositivo pasan a push_enabled = false.

alter table public.notification_preferences
  alter column push_enabled set default false;

update public.notification_preferences np
set push_enabled = false
where push_enabled = true
  and not exists (
    select 1
    from public.device_tokens dt
    where dt.user_id = np.user_id
  );


-- ###########################################################################
-- FILE: noticias_forum.sql
-- ###########################################################################

-- Cofradero · Foro fijo «Noticias»
-- Ejecutar después de roles_v2.sql y notification_social.sql / quiz_daily.sql.
-- Idempotente.

-- ---------------------------------------------------------------------------
-- 1) Pilar
-- ---------------------------------------------------------------------------
insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active, locked_label
) values (
  'noticias',
  'Noticias',
  'Última hora de la Semana Santa de Sevilla.',
  'newspaper_outlined',
  0,
  0,
  0,
  true,
  true,
  null
)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  sort_order = excluded.sort_order,
  is_enabled = excluded.is_enabled,
  is_active = excluded.is_active,
  locked_label = excluded.locked_label;

-- ---------------------------------------------------------------------------
-- 2) Solo admin / moderadores del foro pueden crear noticias
--    Admin → published · Moderador → pending (visto bueno en Junta)
-- ---------------------------------------------------------------------------
create or replace function public.set_noticias_topic_status_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id is distinct from 'noticias' then
    return new;
  end if;

  if public.is_admin_user(new.author_id) then
    new.status := 'published';
  elsif exists (
    select 1
    from public.forum_moderators fm
    where fm.profile_id = new.author_id
      and fm.forum_id = 'noticias'
  ) then
    new.status := 'pending';
  else
    raise exception 'Solo la Junta puede publicar noticias';
  end if;

  return new;
end;
$$;

drop trigger if exists on_noticias_topic_status on public.forum_topics;
create trigger on_noticias_topic_status
  before insert on public.forum_topics
  for each row execute function public.set_noticias_topic_status_on_insert();

-- ---------------------------------------------------------------------------
-- 3) Preferencia de avisos de noticias
-- ---------------------------------------------------------------------------
alter table public.notification_preferences
  add column if not exists notify_news boolean not null default true;

create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'calendar' then coalesce(
      (select notify_calendar from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'quiz' then coalesce(
      (select notify_quiz from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'news' then coalesce(
      (select notify_news from public.notification_preferences where user_id = p_user_id),
      true
    )
    else true
  end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Aviso in-app (y push vía webhook) al publicar una noticia
-- ---------------------------------------------------------------------------
create or replace function public.notify_users_on_noticias_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id is distinct from 'noticias' then
    return new;
  end if;

  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'news_published',
    'Nueva noticia',
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id
    )
  from public.follows f
  join public.profiles p on p.id = f.follower_id
  where f.target_type = 'forum'
    and f.target_id = 'noticias'
    and p.suspended_at is null
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'news');

  return new;
end;
$$;

drop trigger if exists on_noticias_published_notify on public.forum_topics;
create trigger on_noticias_published_notify
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_users_on_noticias_published();


-- ###########################################################################
-- FILE: noticias_related_forum.sql
-- ###########################################################################

-- Cofradero · Noticias asociadas a un foro (etiqueta)
-- Ejecutar después de noticias_forum.sql. Idempotente.

alter table public.forum_topics
  add column if not exists related_forum_id text
  references public.forum_pillars (id) on delete set null;

create index if not exists forum_topics_related_forum_id_idx
  on public.forum_topics (related_forum_id)
  where related_forum_id is not null;

create or replace function public.validate_related_forum_on_topic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.related_forum_id is null then
    return new;
  end if;

  if new.forum_id is distinct from 'noticias' then
    raise exception 'Solo las noticias pueden asociarse a un foro';
  end if;

  if new.related_forum_id = 'noticias' then
    raise exception 'No se puede asociar una noticia al propio canal Noticias';
  end if;

  if new.related_forum_id = new.forum_id then
    raise exception 'El foro asociado no puede ser el mismo del tema';
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_topic_related_forum on public.forum_topics;
create trigger on_forum_topic_related_forum
  before insert or update of related_forum_id, forum_id
  on public.forum_topics
  for each row execute function public.validate_related_forum_on_topic();


-- ###########################################################################
-- FILE: noticias_forum_follow.sql
-- ###########################################################################

-- Cofradero · Seguir el foro Noticias
-- Ejecutar después de noticias_forum.sql y topic_follows.sql. Idempotente.
--
-- El botón «Seguir» en Noticias guarda follows(target_type='forum', target_id='noticias').
-- Al publicar una noticia, solo reciben aviso quienes siguen ese foro
-- (y tienen notify_news activo).

-- ---------------------------------------------------------------------------
-- 1) Permitir seguir un foro (además de hashtag / perfil / hilo)
-- ---------------------------------------------------------------------------
alter table public.follows drop constraint if exists follows_target_type_check;
alter table public.follows add constraint follows_target_type_check
  check (target_type in ('hashtag', 'profile', 'topic', 'forum'));

-- ---------------------------------------------------------------------------
-- 2) Aviso solo a seguidores de Noticias
-- ---------------------------------------------------------------------------
create or replace function public.notify_users_on_noticias_published()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id is distinct from 'noticias' then
    return new;
  end if;

  if new.status <> 'published' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'published' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'news_published',
    'Nueva noticia',
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id
    )
  from public.follows f
  join public.profiles p on p.id = f.follower_id
  where f.target_type = 'forum'
    and f.target_id = 'noticias'
    and p.suspended_at is null
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'news');

  return new;
end;
$$;

drop trigger if exists on_noticias_published_notify on public.forum_topics;
create trigger on_noticias_published_notify
  after insert or update of status on public.forum_topics
  for each row execute function public.notify_users_on_noticias_published();


-- ###########################################################################
-- FILE: hermandad_official_edit.sql
-- ###########################################################################

-- Cofradero · editar y fijar comunicados oficiales publicados
-- Ejecutar después de hermandad_official_posts.sql y forum_official_post_images.sql.

create or replace function public.update_official_hermandad_post(
  p_reply_id uuid,
  p_content text,
  p_official_category text,
  p_image_url text default null,
  p_clear_image boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
  v_forum_id text;
  v_content text := trim(coalesce(p_content, ''));
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if coalesce(v_reply.is_official, false) = false then
    raise exception 'not_official';
  end if;

  if v_reply.deleted_at is not null then
    raise exception 'deleted';
  end if;

  select forum_id into v_forum_id
  from public.forum_topics
  where id = v_reply.topic_id;

  if v_forum_id is distinct from 'hermandades' then
    raise exception 'forbidden';
  end if;

  if not public.can_create_official_hermandad_post(auth.uid(), v_reply.topic_id) then
    raise exception 'forbidden';
  end if;

  if p_official_category not in ('noticia', 'culto', 'acto', 'patrimonio') then
    raise exception 'invalid_category';
  end if;

  if char_length(v_content) > 8000 then
    raise exception 'invalid_content';
  end if;

  if char_length(v_content) < 1
     and p_clear_image
     and (v_reply.image_url is null or trim(v_reply.image_url) = '') then
    raise exception 'invalid_content';
  end if;

  update public.forum_replies
  set content = v_content,
      official_category = p_official_category,
      image_url = case
        when p_clear_image then null
        when p_image_url is not null then nullif(trim(p_image_url), '')
        else image_url
      end,
      edited_at = now()
  where id = p_reply_id;
end;
$$;

create or replace function public.set_official_hermandad_post_pinned(
  p_reply_id uuid,
  p_pinned boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reply public.forum_replies%rowtype;
  v_forum_id text;
begin
  if auth.uid() is null then
    raise exception 'auth_required';
  end if;

  select * into v_reply
  from public.forum_replies
  where id = p_reply_id;

  if not found then
    raise exception 'not_found';
  end if;

  if coalesce(v_reply.is_official, false) = false or v_reply.deleted_at is not null then
    raise exception 'forbidden';
  end if;

  select forum_id into v_forum_id
  from public.forum_topics
  where id = v_reply.topic_id;

  if v_forum_id is distinct from 'hermandades' then
    raise exception 'forbidden';
  end if;

  if not public.can_create_official_hermandad_post(auth.uid(), v_reply.topic_id) then
    raise exception 'forbidden';
  end if;

  if coalesce(p_pinned, false) then
    update public.forum_replies
    set is_featured = false
    where topic_id = v_reply.topic_id
      and coalesce(is_official, false) = true
      and id is distinct from p_reply_id;
  end if;

  update public.forum_replies
  set is_featured = coalesce(p_pinned, false)
  where id = p_reply_id;
end;
$$;

grant execute on function public.update_official_hermandad_post(uuid, text, text, text, boolean)
  to authenticated;
grant execute on function public.set_official_hermandad_post_pinned(uuid, boolean)
  to authenticated;


-- ###########################################################################
-- FILE: hermandad_scheduled_posts.sql
-- ###########################################################################

-- Cofradeo · publicaciones programadas en tablones de hermandades
-- Ejecutar después de hermandad_official_posts.sql

create table if not exists public.hermandad_scheduled_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_handle text not null,
  topic_id text not null references public.forum_topics (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  official_category text not null default 'noticia'
    check (official_category in ('noticia', 'culto', 'acto', 'patrimonio')),
  scheduled_at timestamptz,
  status text not null default 'scheduled'
    check (status in ('draft', 'scheduled', 'published', 'cancelled')),
  published_reply_id uuid references public.forum_replies (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Idempotente: aplicar también si la tabla ya existía (versión sin borradores).
alter table public.hermandad_scheduled_posts
  alter column scheduled_at drop not null;

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_status_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_status_check
  check (status in ('draft', 'scheduled', 'published', 'cancelled'));

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_scheduled_at_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_scheduled_at_check
  check (
    (status = 'draft' and scheduled_at is null)
    or (status in ('scheduled', 'published', 'cancelled') and scheduled_at is not null)
  );

create index if not exists hermandad_scheduled_posts_due_idx
  on public.hermandad_scheduled_posts (scheduled_at)
  where status = 'scheduled';

create index if not exists hermandad_scheduled_posts_author_idx
  on public.hermandad_scheduled_posts (author_id, status, scheduled_at desc);

alter table public.hermandad_scheduled_posts enable row level security;

drop policy if exists "Autor lee sus publicaciones programadas" on public.hermandad_scheduled_posts;
create policy "Autor lee sus publicaciones programadas"
  on public.hermandad_scheduled_posts for select
  using (
    author_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'moderator')
        and p.suspended_at is null
    )
  );

drop policy if exists "Hermandad programa publicaciones oficiales" on public.hermandad_scheduled_posts;
create policy "Hermandad programa publicaciones oficiales"
  on public.hermandad_scheduled_posts for insert
  with check (
    author_id = auth.uid()
    and public.can_create_official_hermandad_post(auth.uid(), topic_id)
    and (
      (
        status = 'draft'
        and scheduled_at is null
      )
      or (
        status = 'scheduled'
        and scheduled_at is not null
        and scheduled_at > now() + interval '5 minutes'
      )
    )
  );

drop policy if exists "Autor edita publicaciones programadas pendientes" on public.hermandad_scheduled_posts;
create policy "Autor edita publicaciones programadas pendientes"
  on public.hermandad_scheduled_posts for update
  using (
    author_id = auth.uid()
    and status in ('draft', 'scheduled')
  )
  with check (
    author_id = auth.uid()
    and public.can_create_official_hermandad_post(auth.uid(), topic_id)
    and (
      status = 'cancelled'
      or (
        status = 'draft'
        and scheduled_at is null
      )
      or (
        status = 'scheduled'
        and scheduled_at is not null
        and scheduled_at > now() + interval '5 minutes'
      )
    )
  );

drop policy if exists "Autor elimina borradores" on public.hermandad_scheduled_posts;
create policy "Autor elimina borradores"
  on public.hermandad_scheduled_posts for delete
  using (
    author_id = auth.uid()
    and status = 'draft'
  );

create index if not exists hermandad_scheduled_posts_drafts_idx
  on public.hermandad_scheduled_posts (author_id, updated_at desc)
  where status = 'draft';

create or replace function public.publish_due_hermandad_scheduled_posts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_reply_id uuid;
  v_count integer := 0;
begin
  for v_row in
    select *
    from public.hermandad_scheduled_posts
    where status = 'scheduled'
      and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    insert into public.forum_replies (
      topic_id,
      author_id,
      author_handle,
      content,
      is_official,
      official_category
    ) values (
      v_row.topic_id,
      v_row.author_id,
      v_row.author_handle,
      v_row.content,
      true,
      v_row.official_category
    )
    returning id into v_reply_id;

    update public.hermandad_scheduled_posts
    set status = 'published',
        published_reply_id = v_reply_id,
        updated_at = now()
    where id = v_row.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.publish_due_hermandad_scheduled_posts() to authenticated;

-- Opcional (pg_cron en Supabase): publicar cada minuto
-- select cron.schedule(
--   'publish-hermandad-scheduled-posts',
--   '* * * * *',
--   $$ select public.publish_due_hermandad_scheduled_posts(); $$
-- );


-- ###########################################################################
-- FILE: hermandad_scheduled_posts_drafts.sql
-- ###########################################################################

-- Cofradeo · borradores en publicaciones de hermandades
-- Solo si aplicaste hermandad_scheduled_posts.sql ANTES de que incluyera borradores.
-- Si vuelves a ejecutar el SQL principal actualizado, NO hace falta este archivo.

alter table public.hermandad_scheduled_posts
  alter column scheduled_at drop not null;

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_status_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_status_check
  check (status in ('draft', 'scheduled', 'published', 'cancelled'));

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_scheduled_at_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_scheduled_at_check
  check (
    (status = 'draft' and scheduled_at is null)
    or (status in ('scheduled', 'published', 'cancelled') and scheduled_at is not null)
  );

drop policy if exists "Hermandad programa publicaciones oficiales" on public.hermandad_scheduled_posts;
create policy "Hermandad programa publicaciones oficiales"
  on public.hermandad_scheduled_posts for insert
  with check (
    author_id = auth.uid()
    and public.can_create_official_hermandad_post(auth.uid(), topic_id)
    and (
      (
        status = 'draft'
        and scheduled_at is null
      )
      or (
        status = 'scheduled'
        and scheduled_at is not null
        and scheduled_at > now() + interval '5 minutes'
      )
    )
  );

drop policy if exists "Autor edita publicaciones programadas pendientes" on public.hermandad_scheduled_posts;
create policy "Autor edita publicaciones programadas pendientes"
  on public.hermandad_scheduled_posts for update
  using (
    author_id = auth.uid()
    and status in ('draft', 'scheduled')
  )
  with check (
    author_id = auth.uid()
    and public.can_create_official_hermandad_post(auth.uid(), topic_id)
    and (
      status = 'cancelled'
      or (
        status = 'draft'
        and scheduled_at is null
      )
      or (
        status = 'scheduled'
        and scheduled_at is not null
        and scheduled_at > now() + interval '5 minutes'
      )
    )
  );

drop policy if exists "Autor elimina borradores" on public.hermandad_scheduled_posts;
create policy "Autor elimina borradores"
  on public.hermandad_scheduled_posts for delete
  using (
    author_id = auth.uid()
    and status = 'draft'
  );

create index if not exists hermandad_scheduled_posts_drafts_idx
  on public.hermandad_scheduled_posts (author_id, updated_at desc)
  where status = 'draft';


-- ###########################################################################
-- FILE: hermandad_official_notify.sql
-- ###########################################################################

-- Cofradero · notificaciones al publicar en hermandades que sigues
-- Ejecutar después de notification_social.sql y hermandad_official_posts.sql.

create or replace function public.official_category_label(p_category text)
returns text
language sql
immutable
as $$
  select case p_category
    when 'culto' then 'Cultos'
    when 'acto' then 'Actos'
    when 'patrimonio' then 'Patrimonio'
    else 'Noticias'
  end;
$$;

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_handle text;
  v_section text;
  v_excerpt text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  -- Publicaciones oficiales de Hermandades: aviso específico a seguidores
  if v_topic.forum_id = 'hermandades'
     and coalesce(new.is_official, false) then
    v_section := public.official_category_label(new.official_category);
    v_excerpt := left(
      regexp_replace(coalesce(new.content, ''), '\s+', ' ', 'g'),
      90
    );

    insert into public.notifications (user_id, type, title, subtitle, payload)
    select
      f.follower_id,
      'topic_activity',
      'Nueva publicación en una hermandad que sigues',
      v_section || ' · ' || left(v_topic.title, 70),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text,
        'officialCategory', coalesce(new.official_category, 'noticia')
      )
    from public.follows f
    where f.target_type = 'topic'
      and f.target_id = v_topic.id
      and f.follower_id is distinct from new.author_id
      and public.notify_pref_enabled(f.follower_id, 'topics')
      and public.is_not_blocked(f.follower_id, new.author_id);

    -- Menciones en el comunicado
    if new.author_id is not null then
      for v_handle in
        select distinct lower(m[1])
        from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
      loop
        insert into public.notifications (user_id, type, title, subtitle, payload)
        select
          p.id,
          'mention',
          new.author_handle || ' te mencionó',
          left(coalesce(new.content, ''), 80),
          jsonb_build_object(
            'forumId', v_topic.forum_id,
            'topicId', v_topic.id,
            'profileId', new.author_id::text,
            'replyId', new.id::text
          )
        from public.profiles p
        where lower(regexp_replace(p.handle, '^@', '')) = v_handle
          and p.id is distinct from new.author_id
          and public.notify_pref_enabled(p.id, 'mentions')
          and public.is_not_blocked(p.id, new.author_id);
      end loop;
    end if;

    return new;
  end if;

  -- Autor del tema (foros normales)
  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  -- Hashtags seguidos
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(v_topic.title, '') || ' ' ||
        coalesce(v_topic.excerpt, '') || ' ' ||
        coalesce(v_topic.body, '') || ' ' ||
        coalesce(new.content, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  -- Hilos seguidos
  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  -- Menciones @handle
  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: hermandad_official_post_notify.sql
-- ###########################################################################

-- Cofradeo · avisar a seguidores del perfil cuando una hermandad publica oficialmente
-- Ejecutar después de: notification_social.sql (o mention_reply_scroll.sql),
-- hermandad_official_posts.sql y push_webhook_trigger.sql si usas FCM.
--
-- Comportamiento:
-- · Publicación oficial en foro hermandades (inmediata o programada) → user_post
--   a quien sigue el perfil de la cuenta oficial (notify_profiles).
-- · Si además sigue el tablón (topic), solo recibe topic_activity (evita duplicado).

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_topic_text text;
  v_handle text;
  v_author record;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_topic_text := lower(
    regexp_replace(
      coalesce(v_topic.title, '') || ' ' ||
      coalesce(v_topic.excerpt, '') || ' ' ||
      coalesce(v_topic.body, ''),
      '[\s#]+',
      '',
      'g'
    )
  );

  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and v_topic_text like '%' || lower(
      regexp_replace(replace(f.target_id, '#', ''), '[\s#]+', '', 'g')
    ) || '%';

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  -- Seguidores de la cuenta oficial en publicaciones de hermandad
  if coalesce(new.is_official, false)
     and v_topic.forum_id = 'hermandades'
     and new.author_id is not null then
    select display_name, handle
    into v_author
    from public.profiles
    where id = new.author_id;

    if found then
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        f.follower_id,
        'user_post',
        coalesce(v_author.display_name, '@' || v_author.handle) || ' publicó',
        left(coalesce(nullif(trim(new.content), ''), v_topic.title), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'replyId', new.id::text,
          'profileId', new.author_id::text
        )
      from public.follows f
      where f.target_type = 'profile'
        and f.target_id = new.author_id::text
        and f.follower_id is distinct from new.author_id
        and public.notify_pref_enabled(f.follower_id, 'profiles')
        and public.is_not_blocked(f.follower_id, new.author_id)
        and not exists (
          select 1
          from public.follows tf
          where tf.follower_id = f.follower_id
            and tf.target_type = 'topic'
            and tf.target_id = v_topic.id
        );
    end if;
  end if;

  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: hermandad_follow_notify_sections.sql
-- ###########################################################################

-- Cofradero · avisos por sección al seguir una hermandad
-- Ejecutar después de hermandad_official_notify.sql

alter table public.follows
  add column if not exists notify_official_categories text[];

comment on column public.follows.notify_official_categories is
  'Tablones hermandad: null = todas las secciones; array de noticia|culto|acto|patrimonio';

create or replace function public.notify_on_forum_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic record;
  v_handle text;
  v_section text;
  v_excerpt text;
  v_category text;
begin
  perform set_config('row_security', 'off', true);

  select id, forum_id, title, excerpt, body, author_id
  into v_topic
  from public.forum_topics
  where id = new.topic_id;

  if not found then
    return new;
  end if;

  v_category := coalesce(new.official_category, 'noticia');

  if v_topic.forum_id = 'hermandades'
     and coalesce(new.is_official, false) then
    v_section := public.official_category_label(new.official_category);
    v_excerpt := left(
      regexp_replace(coalesce(new.content, ''), '\s+', ' ', 'g'),
      90
    );

    insert into public.notifications (user_id, type, title, subtitle, payload)
    select
      f.follower_id,
      'topic_activity',
      'Nueva publicación en una hermandad que sigues',
      v_section || ' · ' || left(v_topic.title, 70),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text,
        'officialCategory', v_category
      )
    from public.follows f
    where f.target_type = 'topic'
      and f.target_id = v_topic.id
      and f.follower_id is distinct from new.author_id
      and public.notify_pref_enabled(f.follower_id, 'topics')
      and public.is_not_blocked(f.follower_id, new.author_id)
      and (
        f.notify_official_categories is null
        or v_category = any (f.notify_official_categories)
      );

    if new.author_id is not null then
      for v_handle in
        select distinct lower(m[1])
        from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
      loop
        insert into public.notifications (user_id, type, title, subtitle, payload)
        select
          p.id,
          'mention',
          new.author_handle || ' te mencionó',
          left(coalesce(new.content, ''), 80),
          jsonb_build_object(
            'forumId', v_topic.forum_id,
            'topicId', v_topic.id,
            'profileId', new.author_id::text,
            'replyId', new.id::text
          )
        from public.profiles p
        where lower(regexp_replace(p.handle, '^@', '')) = v_handle
          and p.id is distinct from new.author_id
          and public.notify_pref_enabled(p.id, 'mentions')
          and public.is_not_blocked(p.id, new.author_id);
      end loop;
    end if;

    return new;
  end if;

  if v_topic.author_id is not null
     and new.author_id is not null
     and v_topic.author_id is distinct from new.author_id
     and public.is_not_blocked(v_topic.author_id, new.author_id) then
    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      v_topic.author_id,
      'user_reply',
      'Nueva respuesta en tu hilo',
      new.author_handle || ' · ' || left(v_topic.title, 80),
      jsonb_build_object(
        'forumId', v_topic.forum_id,
        'topicId', v_topic.id,
        'replyId', new.id::text
      )
    );
  end if;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'hashtag_activity',
    'Nuevo comentario en ' || f.target_id,
    left(v_topic.title, 80) || ' · ' || new.author_handle,
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'hashtag'
    and f.follower_id is distinct from new.author_id
    and public.notify_pref_enabled(f.follower_id, 'hashtags')
    and public.is_not_blocked(f.follower_id, new.author_id)
    and lower(f.target_id) in (
      select lower('#' || (m)[1])
      from regexp_matches(
        coalesce(v_topic.title, '') || ' ' ||
        coalesce(v_topic.excerpt, '') || ' ' ||
        coalesce(v_topic.body, '') || ' ' ||
        coalesce(new.content, ''),
        '#([A-Za-z0-9_ÁÉÍÓÚáéíóúÑñ]+)',
        'g'
      ) as m
    );

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    f.follower_id,
    'topic_activity',
    'Nueva respuesta en un hilo que sigues',
    new.author_handle || ' · ' || left(v_topic.title, 80),
    jsonb_build_object(
      'forumId', v_topic.forum_id,
      'topicId', v_topic.id,
      'replyId', new.id::text
    )
  from public.follows f
  where f.target_type = 'topic'
    and f.target_id = v_topic.id
    and f.follower_id is distinct from new.author_id
    and f.follower_id is distinct from v_topic.author_id
    and public.notify_pref_enabled(f.follower_id, 'topics')
    and public.is_not_blocked(f.follower_id, new.author_id);

  if new.author_id is not null then
    for v_handle in
      select distinct lower(m[1])
      from regexp_matches(coalesce(new.content, ''), '@([a-zA-Z0-9_]+)', 'g') as m
    loop
      insert into public.notifications (user_id, type, title, subtitle, payload)
      select
        p.id,
        'mention',
        new.author_handle || ' te mencionó',
        left(coalesce(new.content, ''), 80),
        jsonb_build_object(
          'forumId', v_topic.forum_id,
          'topicId', v_topic.id,
          'profileId', new.author_id::text,
          'replyId', new.id::text
        )
      from public.profiles p
      where lower(regexp_replace(p.handle, '^@', '')) = v_handle
        and p.id is distinct from new.author_id
        and public.notify_pref_enabled(p.id, 'mentions')
        and public.is_not_blocked(p.id, new.author_id);
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists on_forum_reply_notify on public.forum_replies;
create trigger on_forum_reply_notify
  after insert on public.forum_replies
  for each row execute function public.notify_on_forum_reply();


-- ###########################################################################
-- FILE: forum_official_post_images.sql
-- ###########################################################################

-- Cofradero · imágenes en publicaciones oficiales de Hermandades
-- Ejecutar después de hermandad_official_posts.sql y hermandad_scheduled_posts.sql.

alter table public.forum_replies
  add column if not exists image_url text;

alter table public.hermandad_scheduled_posts
  add column if not exists image_url text;

create or replace function public.publish_due_hermandad_scheduled_posts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_reply_id uuid;
  v_count integer := 0;
begin
  for v_row in
    select *
    from public.hermandad_scheduled_posts
    where status = 'scheduled'
      and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    insert into public.forum_replies (
      topic_id,
      author_id,
      author_handle,
      content,
      is_official,
      official_category,
      image_url
    ) values (
      v_row.topic_id,
      v_row.author_id,
      v_row.author_handle,
      v_row.content,
      true,
      v_row.official_category,
      v_row.image_url
    )
    returning id into v_reply_id;

    update public.hermandad_scheduled_posts
    set status = 'published',
        published_reply_id = v_reply_id,
        updated_at = now()
    where id = v_row.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'forum-post-images',
  'forum-post-images',
  true,
  5242880,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Imagenes publicacion lectura publica" on storage.objects;
create policy "Imagenes publicacion lectura publica"
  on storage.objects for select
  using (bucket_id = 'forum-post-images');

drop policy if exists "Oficial sube imagenes publicacion" on storage.objects;
create policy "Oficial sube imagenes publicacion"
  on storage.objects for insert
  with check (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  );

drop policy if exists "Oficial actualiza imagenes publicacion" on storage.objects;
create policy "Oficial actualiza imagenes publicacion"
  on storage.objects for update
  using (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  )
  with check (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  );

drop policy if exists "Oficial borra imagenes publicacion" on storage.objects;
create policy "Oficial borra imagenes publicacion"
  on storage.objects for delete
  using (
    bucket_id = 'forum-post-images'
    and public.can_create_official_hermandad_post(
      auth.uid(),
      (storage.foldername(name))[1]
    )
  );


-- ###########################################################################
-- FILE: junta_create_hermandad_account.sql
-- ###########################################################################

-- Cofradero · Alta de cuentas hermandad desde Junta
-- Ejecutar en SQL Editor (después de schema.sql / profile_verification.sql).
--
-- La creación de auth.users la hace la Edge Function `create-hermandad-account`
-- (service role). Este SQL deja el trigger listo para metadata brotherhood.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  raw_handle text;
  raw_account_type text;
  raw_verified boolean;
begin
  raw_handle := coalesce(
    new.raw_user_meta_data ->> 'handle',
    split_part(new.email, '@', 1)
  );
  raw_handle := lower(regexp_replace(raw_handle, '[^a-z0-9_]', '', 'g'));
  if raw_handle = '' then
    raw_handle := 'user_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;

  raw_account_type := coalesce(
    new.raw_user_meta_data ->> 'account_type',
    'cofrade'
  );
  if raw_account_type not in ('cofrade', 'brotherhood') then
    raw_account_type := 'cofrade';
  end if;

  raw_verified := coalesce(
    (new.raw_user_meta_data ->> 'verified')::boolean,
    false
  );

  insert into public.profiles (
    id,
    handle,
    display_name,
    account_type,
    verified
  )
  values (
    new.id,
    raw_handle,
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(new.email, '@', 1)
    ),
    raw_account_type,
    raw_verified
  );
  return new;
end;
$$;

-- Despliegue Edge Function:
--   supabase functions deploy create-hermandad-account
-- Secretos: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
-- (normalmente ya inyectados en el runtime de Functions).


-- ###########################################################################
-- FILE: hermandades_todos_los_dias.sql
-- ###########################################################################

-- Cofradero · Hermandades por día (Sevilla)
-- Ejecutar después de schema.sql. Es idempotente y no duplica temas existentes.

insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active, locked_label
) values (
  'hermandades',
  'Hermandades',
  'Sigue las noticias y avisos de cada hermandad por día.',
  'groups_outlined',
  4,
  0,
  0,
  true,
  true,
  null
)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  sort_order = excluded.sort_order,
  is_enabled = excluded.is_enabled,
  is_active = excluded.is_active,
  locked_label = excluded.locked_label;

update public.forum_pillars
set sort_order = case id
  when 'semana-santa' then 5
  when 'cuaresma' then 6
  when 'glorias' then 7
  else sort_order
end
where id in ('semana-santa', 'cuaresma', 'glorias');

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status, created_at
)
select
  day_slug || '-' || hermandad_slug,
  'hermandades',
  '@cofradeo',
  day_label || ' · ' || hermandad_name,
  'Espacio para noticias, horarios, avisos e información oficial de ' || hermandad_name || '.',
  'Este es el espacio de seguimiento de ' || hermandad_name || ' para ' || day_label || '.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
  false,
  0,
  0,
  'published',
  now() - (sort_order || ' minutes')::interval
from (values
  ('Viernes de Dolores', 'viernes-dolores', 'Bendición y Esperanza', 'bendicion-esperanza', 1),
  ('Viernes de Dolores', 'viernes-dolores', 'Pino Montano', 'pino-montano', 2),
  ('Viernes de Dolores', 'viernes-dolores', 'La Misión', 'la-mision', 3),
  ('Viernes de Dolores', 'viernes-dolores', 'Bellavista', 'bellavista', 4),
  ('Viernes de Dolores', 'viernes-dolores', 'La Corona', 'la-corona', 5),
  ('Viernes de Dolores', 'viernes-dolores', 'Pasión y Muerte', 'pasion-y-muerte', 6),
  ('Sábado de Pasión', 'sabado-pasion', 'Padre Pío', 'padre-pio', 7),
  ('Sábado de Pasión', 'sabado-pasion', 'La Milagrosa', 'la-milagrosa', 8),
  ('Sábado de Pasión', 'sabado-pasion', 'Torreblanca', 'torreblanca', 9),
  ('Sábado de Pasión', 'sabado-pasion', 'San José Obrero', 'san-jose-obrero', 10),
  ('Sábado de Pasión', 'sabado-pasion', 'Divino Perdón', 'divino-perdon', 11),
  ('Domingo de Ramos', 'domingo-ramos', 'La Borriquita', 'la-borriquita', 12),
  ('Domingo de Ramos', 'domingo-ramos', 'La Cena', 'la-cena', 13),
  ('Domingo de Ramos', 'domingo-ramos', 'Jesús Despojado', 'jesus-despojado', 14),
  ('Domingo de Ramos', 'domingo-ramos', 'La Hiniesta', 'la-hiniesta', 15),
  ('Domingo de Ramos', 'domingo-ramos', 'La Paz', 'la-paz', 16),
  ('Domingo de Ramos', 'domingo-ramos', 'San Roque', 'san-roque', 17),
  ('Domingo de Ramos', 'domingo-ramos', 'La Estrella', 'la-estrella', 18),
  ('Domingo de Ramos', 'domingo-ramos', 'La Amargura', 'la-amargura', 19),
  ('Domingo de Ramos', 'domingo-ramos', 'El Amor', 'el-amor', 20),
  ('Lunes Santo', 'lunes-santo', 'San Pablo', 'san-pablo', 21),
  ('Lunes Santo', 'lunes-santo', 'La Redención', 'la-redencion', 22),
  ('Lunes Santo', 'lunes-santo', 'Santa Genoveva', 'santa-genoveva', 23),
  ('Lunes Santo', 'lunes-santo', 'Santa Marta', 'santa-marta', 24),
  ('Lunes Santo', 'lunes-santo', 'San Gonzalo', 'san-gonzalo', 25),
  ('Lunes Santo', 'lunes-santo', 'Vera Cruz', 'vera-cruz', 26),
  ('Lunes Santo', 'lunes-santo', 'Las Penas', 'las-penas', 27),
  ('Lunes Santo', 'lunes-santo', 'Las Aguas', 'las-aguas', 28),
  ('Lunes Santo', 'lunes-santo', 'El Museo', 'el-museo', 29),
  ('Martes Santo', 'martes-santo', 'El Cerro', 'el-cerro', 30),
  ('Martes Santo', 'martes-santo', 'San Esteban', 'san-esteban', 31),
  ('Martes Santo', 'martes-santo', 'La Candelaria', 'la-candelaria', 32),
  ('Martes Santo', 'martes-santo', 'San Benito', 'san-benito', 33),
  ('Martes Santo', 'martes-santo', 'Los Javieres', 'los-javieres', 34),
  ('Martes Santo', 'martes-santo', 'El Dulce Nombre', 'el-dulce-nombre', 35),
  ('Martes Santo', 'martes-santo', 'Los Estudiantes', 'los-estudiantes', 36),
  ('Martes Santo', 'martes-santo', 'Santa Cruz', 'santa-cruz', 37),
  ('Miércoles Santo', 'miercoles-santo', 'El Carmen Doloroso', 'el-carmen-doloroso', 38),
  ('Miércoles Santo', 'miercoles-santo', 'El Buen Fin', 'el-buen-fin', 39),
  ('Miércoles Santo', 'miercoles-santo', 'La Sed', 'la-sed', 40),
  ('Miércoles Santo', 'miercoles-santo', 'San Bernardo', 'san-bernardo', 41),
  ('Miércoles Santo', 'miercoles-santo', 'La Lanzada', 'la-lanzada', 42),
  ('Miércoles Santo', 'miercoles-santo', 'El Baratillo', 'el-baratillo', 43),
  ('Miércoles Santo', 'miercoles-santo', 'Los Panaderos', 'los-panaderos', 44),
  ('Miércoles Santo', 'miercoles-santo', 'Cristo de Burgos', 'cristo-de-burgos', 45),
  ('Miércoles Santo', 'miercoles-santo', 'Las Siete Palabras', 'las-siete-palabras', 46),
  ('Jueves Santo', 'jueves-santo', 'Los Negritos', 'los-negritos', 47),
  ('Jueves Santo', 'jueves-santo', 'La Exaltación', 'la-exaltacion', 48),
  ('Jueves Santo', 'jueves-santo', 'Las Cigarreras', 'las-cigarreras', 49),
  ('Jueves Santo', 'jueves-santo', 'Montesión', 'montesion', 50),
  ('Jueves Santo', 'jueves-santo', 'La Quinta Angustia', 'la-quinta-angustia', 51),
  ('Jueves Santo', 'jueves-santo', 'El Valle', 'el-valle', 52),
  ('Jueves Santo', 'jueves-santo', 'Pasión', 'pasion', 53),
  ('Madrugá', 'madruga', 'El Silencio', 'el-silencio', 54),
  ('Madrugá', 'madruga', 'El Gran Poder', 'el-gran-poder', 55),
  ('Madrugá', 'madruga', 'La Macarena', 'la-macarena', 56),
  ('Madrugá', 'madruga', 'El Calvario', 'el-calvario', 57),
  ('Madrugá', 'madruga', 'La Esperanza de Triana', 'la-esperanza-de-triana', 58),
  ('Madrugá', 'madruga', 'Los Gitanos', 'los-gitanos', 59),
  ('Viernes Santo', 'viernes-santo', 'La Carretería', 'la-carreteria', 60),
  ('Viernes Santo', 'viernes-santo', 'Soledad de San Buenaventura', 'soledad-san-buenaventura', 61),
  ('Viernes Santo', 'viernes-santo', 'El Cachorro', 'el-cachorro', 62),
  ('Viernes Santo', 'viernes-santo', 'La O', 'la-o', 63),
  ('Viernes Santo', 'viernes-santo', 'San Isidoro', 'san-isidoro', 64),
  ('Viernes Santo', 'viernes-santo', 'Montserrat', 'montserrat', 65),
  ('Viernes Santo', 'viernes-santo', 'La Mortaja', 'la-mortaja', 66),
  ('Sábado Santo', 'sabado-santo', 'El Sol', 'el-sol', 67),
  ('Sábado Santo', 'sabado-santo', 'Los Servitas', 'los-servitas', 68),
  ('Sábado Santo', 'sabado-santo', 'La Trinidad', 'la-trinidad', 69),
  ('Sábado Santo', 'sabado-santo', 'El Santo Entierro', 'el-santo-entierro', 70),
  ('Sábado Santo', 'sabado-santo', 'La Soledad de San Lorenzo', 'la-soledad-de-san-lorenzo', 71),
  ('Domingo de Resurrección', 'domingo-resurreccion', 'La Resurrección', 'la-resurreccion', 72)
) as hermandades(day_label, day_slug, hermandad_name, hermandad_slug, sort_order)
on conflict (id) do nothing;

do $$
begin
  if to_regprocedure('public.refresh_forum_pillar_stats(text)') is not null then
    execute 'select public.refresh_forum_pillar_stats($1)' using 'hermandades';
  end if;
end;
$$;


-- ###########################################################################
-- FILE: pinned_topics.sql
-- ###########################################################################

-- Cofradero · Temas fijos (pinned) dentro de pilares + ocultar pilares de temporada
-- Ejecutar después de schema.sql. Idempotente.

alter table public.forum_topics
  add column if not exists is_pinned boolean not null default false;

alter table public.forum_topics
  add column if not exists pin_sort_order int not null default 0;

alter table public.forum_topics
  add column if not exists is_system boolean not null default false;

alter table public.forum_topics
  add column if not exists season_key text
    check (
      season_key is null
      or season_key in ('cuaresma', 'semana_santa', 'glorias')
    );

alter table public.forum_topics
  add column if not exists icon_key text;

alter table public.forum_topics
  add column if not exists cover_image_url text;

create index if not exists forum_topics_pinned_idx
  on public.forum_topics (forum_id, is_pinned, pin_sort_order);

-- Los pilares de temporada pasan a temas fijos dentro del Círculo Cofrade.
update public.forum_pillars
set is_enabled = false
where id in ('cuaresma', 'glorias', 'semana-santa');

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status,
  is_pinned, pin_sort_order, is_system, season_key, icon_key, created_at
) values
  (
    'circulo-cuaresma', 'foro-cofradiero', '@cofradeo',
    'Cuaresma',
    'Cultos, estaciones, pregones y camino hacia la Semana Mayor.',
    'Espacio para hablar de la Cuaresma: cultos, estaciones de penitencia, pregones, cartelería y camino hacia la Semana Mayor.\n\nComparte noticias, dudas y conversación con la comunidad cofrade.',
    false, 0, 0, 'published',
    true, 1, true, 'cuaresma', 'filter_vintage_outlined', now() - interval '30 days'
  ),
  (
    'circulo-semana-santa', 'foro-cofradiero', '@cofradeo',
    'Semana Santa',
    'Todo sobre la Semana Mayor: procesiones, horarios y noticias.',
    'El hilo de la Semana Mayor: procesiones, horarios, itinerarios, avisos y noticias de las jornadas grandes.\n\nCentraliza aquí la conversación cofrade de la Semana Santa en Sevilla.',
    false, 0, 0, 'published',
    true, 2, true, 'semana_santa', 'account_balance', now() - interval '29 days'
  ),
  (
    'circulo-glorias', 'foro-cofradiero', '@cofradeo',
    'Glorias',
    'Procesiones de gloria, Domingo de Resurrección y cultos de gloria.',
    'Todo sobre el tiempo de Glorias: Domingo de Resurrección, procesiones de gloria, cultos y la actualidad cofrade después de la Semana Mayor.\n\nComparte noticias, horarios y conversación con la comunidad.',
    false, 0, 0, 'published',
    true, 3, true, 'glorias', 'wb_sunny_outlined', now() - interval '28 days'
  ),
  (
    'martillo-cambio-capataces', 'martillo-trabajadera', '@cofradeo',
    'Cambio de capataces',
    'Rumores, confirmaciones y actualidad de traslados de capataces.',
    'Espacio permanente para la actualidad del costal: cambios de capataces, traslados, nombres que suenan y confirmaciones oficiales.\n\nComparte rumores con respeto y contrasta siempre con fuentes fiables.',
    false, 0, 0, 'published',
    true, 1, true, null, 'workspace_premium_outlined', now() - interval '27 days'
  )
on conflict (id) do update set
  forum_id = excluded.forum_id,
  title = excluded.title,
  excerpt = excluded.excerpt,
  body = excluded.body,
  status = excluded.status,
  is_pinned = excluded.is_pinned,
  pin_sort_order = excluded.pin_sort_order,
  is_system = excluded.is_system,
  season_key = excluded.season_key,
  icon_key = excluded.icon_key;

do $$
begin
  if to_regprocedure('public.refresh_forum_pillar_stats(text)') is not null then
    execute 'select public.refresh_forum_pillar_stats($1)' using 'foro-cofradiero';
    execute 'select public.refresh_forum_pillar_stats($1)' using 'martillo-trabajadera';
  end if;
end;
$$;


-- ###########################################################################
-- FILE: pinned_topics_admin.sql
-- ###########################################################################

-- Cofradero · Ajustes temas destacados (admin)
-- Ejecutar después de pinned_topics.sql y topic_icons.sql. Idempotente.

alter table public.forum_topics
  add column if not exists is_listed boolean not null default true;

-- Semana Santa es tema fijo del Círculo (el pilar legacy queda oculto).
update public.forum_pillars
set
  is_enabled = false,
  locked_label = 'Se activará en Semana Santa'
where id = 'semana-santa';

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status,
  is_pinned, pin_sort_order, is_system, season_key, icon_key, created_at
) values
  (
    'circulo-semana-santa', 'foro-cofradiero', '@cofradeo',
    'Semana Santa',
    'Todo sobre la Semana Mayor: procesiones, horarios y noticias.',
    'El hilo de la Semana Mayor: procesiones, horarios, itinerarios, avisos y noticias de las jornadas grandes.\n\nCentraliza aquí la conversación cofrade de la Semana Santa en Sevilla.',
    false, 0, 0, 'published',
    true, 2, true, 'semana_santa', 'account_balance', now() - interval '29 days'
  )
on conflict (id) do update set
  forum_id = excluded.forum_id,
  title = excluded.title,
  excerpt = excluded.excerpt,
  body = excluded.body,
  status = excluded.status,
  is_pinned = excluded.is_pinned,
  pin_sort_order = excluded.pin_sort_order,
  is_system = excluded.is_system,
  season_key = excluded.season_key,
  icon_key = excluded.icon_key;

update public.forum_topics
set pin_sort_order = case id
  when 'circulo-cuaresma' then 1
  when 'circulo-semana-santa' then 2
  when 'circulo-glorias' then 3
  when 'martillo-cambio-capataces' then 1
  else pin_sort_order
end
where id in (
  'circulo-cuaresma',
  'circulo-semana-santa',
  'circulo-glorias',
  'martillo-cambio-capataces'
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'topic-covers',
  'topic-covers',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Portadas temas lectura publica" on storage.objects;
create policy "Portadas temas lectura publica"
  on storage.objects for select
  using (bucket_id = 'topic-covers');

drop policy if exists "Staff sube portadas temas" on storage.objects;
create policy "Staff sube portadas temas"
  on storage.objects for insert
  with check (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff actualiza portadas temas" on storage.objects;
create policy "Staff actualiza portadas temas"
  on storage.objects for update
  using (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  )
  with check (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff borra portadas temas" on storage.objects;
create policy "Staff borra portadas temas"
  on storage.objects for delete
  using (
    bucket_id = 'topic-covers'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff crea temas fijos" on public.forum_topics;
create policy "Staff crea temas fijos"
  on public.forum_topics for insert
  with check (
    public.is_staff_user(auth.uid())
    and is_system = true
    and is_pinned = true
  );

drop policy if exists "Staff borra temas fijos" on public.forum_topics;
create policy "Staff borra temas fijos"
  on public.forum_topics for delete
  using (
    public.is_staff_user(auth.uid())
    and is_system = true
  );


-- ###########################################################################
-- FILE: forum_trophies.sql
-- ###########################################################################

-- Cofradeo · trofeos y puntos del foro (rangos cofrades)
-- Ejecutar en SQL Editor después de schema.sql y reply_likes_and_moderation.sql
--
-- Modelo: trofeos desbloqueados una vez → suma puntos → rango visible.
-- Catálogo en app: lib/features/forums/constants/cofrade_trophies.dart

alter table public.profiles
  add column if not exists trophy_points int not null default 0;

comment on column public.profiles.trophy_points is
  'Puntos de trofeo del foro (cache). Rango derivado en cliente.';

create table if not exists public.profile_trophies (
  user_id uuid not null references public.profiles (id) on delete cascade,
  trophy_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, trophy_id)
);

create index if not exists profile_trophies_user_idx
  on public.profile_trophies (user_id, unlocked_at desc);

alter table public.profile_trophies enable row level security;

drop policy if exists "Trofeos legibles por todos" on public.profile_trophies;
create policy "Trofeos legibles por todos"
  on public.profile_trophies for select using (true);

drop policy if exists "Solo backend inserta trofeos" on public.profile_trophies;
create policy "Solo backend inserta trofeos"
  on public.profile_trophies for insert
  with check (false);

-- ── Stats agregadas para evaluar trofeos ───────────────────────────────────

create or replace function public.forum_reactions_received(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint
  from public.forum_reply_likes l
  join public.forum_replies r on r.id = l.reply_id
  where r.author_id = p_user_id
    and r.deleted_at is null;
$$;

create or replace function public.forum_valid_reply_count(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint
  from public.forum_replies r
  where r.author_id = p_user_id
    and r.deleted_at is null
    and length(trim(r.content)) >= 20;
$$;

create or replace function public.forum_topics_created_count(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::bigint
  from public.forum_topics t
  where t.author_id = p_user_id
    and t.status = 'published';
$$;

create or replace function public.forum_topic_views_total(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(t.view_count), 0)::bigint
  from public.forum_topics t
  where t.author_id = p_user_id
    and t.status = 'published';
$$;

create or replace function public.forum_max_topic_followers(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(max(fc.cnt), 0)::bigint
  from (
    select count(*) as cnt
    from public.follows f
    join public.forum_topics t on t.id = f.target_id
    where f.target_type = 'topic'
      and t.author_id = p_user_id
      and t.status = 'published'
    group by t.id
  ) fc;
$$;

-- Helper de hashtags (debe existir antes de forum_max_hashtag_followers).
create or replace function public.extract_topic_hashtags(p_title text, p_body text)
returns table (tag text)
language sql
immutable
set search_path = public
as $$
  select distinct m[1]
  from regexp_matches(
    coalesce(p_title, '') || ' ' || coalesce(p_body, ''),
    '#([[:alnum:]_]+)',
    'gi'
  ) as m;
$$;

-- Hashtag popularizado: primer autor publicado que usó el hashtag en un tema.
create or replace function public.forum_max_hashtag_followers(p_user_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  with hashtag_usage as (
    select
      lower(trim(both '#' from h.tag)) as tag,
      t.author_id,
      t.created_at,
      t.id as topic_id
    from public.forum_topics t
    cross join lateral public.extract_topic_hashtags(t.title, t.body) as h(tag)
    where t.status = 'published'
  ),
  pioneers as (
    select distinct on (tag)
      tag,
      author_id
    from hashtag_usage
    order by tag, created_at asc, topic_id asc
  ),
  pioneer_tags as (
    select tag
    from pioneers
    where author_id = p_user_id
  )
  select coalesce(max(fc.cnt), 0)::bigint
  from pioneer_tags pt
  join lateral (
    select count(*) as cnt
    from public.follows f
    where f.target_type = 'hashtag'
      and lower(f.target_id) = pt.tag
  ) fc on true;
$$;

create or replace function public.sync_profile_trophy_points(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_points int;
begin
  select coalesce(sum(
    case trophy_id
      when 'first_reply' then 1
      when 'replies_10' then 2
      when 'replies_30' then 3
      when 'replies_100' then 5
      when 'first_topic' then 3
      when 'topics_5' then 4
      when 'topics_15' then 8
      when 'topics_40' then 12
      when 'topic_views_100' then 2
      when 'topic_views_500' then 5
      when 'topic_views_2000' then 10
      when 'topic_views_10000' then 15
      when 'reactions_1' then 2
      when 'reactions_25' then 5
      when 'reactions_100' then 10
      when 'reactions_250' then 15
      when 'reactions_500' then 20
      when 'followers_5' then 3
      when 'followers_25' then 8
      when 'followers_100' then 15
      when 'hashtag_followers_5' then 4
      when 'hashtag_followers_25' then 10
      when 'topic_followers_10' then 4
      when 'topic_followers_50' then 8
      else 0
    end
  ), 0)
  into v_points
  from public.profile_trophies
  where user_id = p_user_id;

  update public.profiles
  set trophy_points = v_points
  where id = p_user_id;
end;
$$;

grant execute on function public.forum_reactions_received(uuid) to authenticated, anon;
grant execute on function public.forum_valid_reply_count(uuid) to authenticated, anon;
grant execute on function public.forum_topics_created_count(uuid) to authenticated, anon;
grant execute on function public.forum_topic_views_total(uuid) to authenticated, anon;
grant execute on function public.forum_max_topic_followers(uuid) to authenticated, anon;
grant execute on function public.forum_max_hashtag_followers(uuid) to authenticated, anon;

-- ── Desbloqueo automático de trofeos ───────────────────────────────────────

create or replace function public.sync_forum_trophies(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_valid_replies bigint;
  v_topics_created bigint;
  v_topic_views bigint;
  v_reactions bigint;
  v_followers int;
  v_max_topic_followers bigint;
  v_max_hashtag_followers bigint;
begin
  if p_user_id is null then
    return;
  end if;

  v_valid_replies := public.forum_valid_reply_count(p_user_id);
  v_topics_created := public.forum_topics_created_count(p_user_id);
  v_topic_views := public.forum_topic_views_total(p_user_id);
  v_reactions := public.forum_reactions_received(p_user_id);
  v_max_topic_followers := public.forum_max_topic_followers(p_user_id);
  v_max_hashtag_followers := public.forum_max_hashtag_followers(p_user_id);

  select coalesce(follower_count, 0)
  into v_followers
  from public.profiles
  where id = p_user_id;

  if v_valid_replies >= 1 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'first_reply') on conflict do nothing;
  end if;
  if v_valid_replies >= 10 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'replies_10') on conflict do nothing;
  end if;
  if v_valid_replies >= 30 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'replies_30') on conflict do nothing;
  end if;
  if v_valid_replies >= 100 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'replies_100') on conflict do nothing;
  end if;

  if v_topics_created >= 1 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'first_topic') on conflict do nothing;
  end if;
  if v_topics_created >= 5 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topics_5') on conflict do nothing;
  end if;
  if v_topics_created >= 15 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topics_15') on conflict do nothing;
  end if;
  if v_topics_created >= 40 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topics_40') on conflict do nothing;
  end if;

  if v_topic_views >= 100 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topic_views_100') on conflict do nothing;
  end if;
  if v_topic_views >= 500 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topic_views_500') on conflict do nothing;
  end if;
  if v_topic_views >= 2000 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topic_views_2000') on conflict do nothing;
  end if;
  if v_topic_views >= 10000 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topic_views_10000') on conflict do nothing;
  end if;

  if v_reactions >= 1 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'reactions_1') on conflict do nothing;
  end if;
  if v_reactions >= 25 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'reactions_25') on conflict do nothing;
  end if;
  if v_reactions >= 100 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'reactions_100') on conflict do nothing;
  end if;
  if v_reactions >= 250 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'reactions_250') on conflict do nothing;
  end if;
  if v_reactions >= 500 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'reactions_500') on conflict do nothing;
  end if;

  if v_followers >= 5 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'followers_5') on conflict do nothing;
  end if;
  if v_followers >= 25 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'followers_25') on conflict do nothing;
  end if;
  if v_followers >= 100 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'followers_100') on conflict do nothing;
  end if;

  if v_max_hashtag_followers >= 5 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'hashtag_followers_5') on conflict do nothing;
  end if;
  if v_max_hashtag_followers >= 25 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'hashtag_followers_25') on conflict do nothing;
  end if;

  if v_max_topic_followers >= 10 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topic_followers_10') on conflict do nothing;
  end if;
  if v_max_topic_followers >= 50 then
    insert into public.profile_trophies (user_id, trophy_id)
    values (p_user_id, 'topic_followers_50') on conflict do nothing;
  end if;

  perform public.sync_profile_trophy_points(p_user_id);
end;
$$;

create or replace function public.forum_hashtag_pioneer_id(p_tag text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  with hashtag_usage as (
    select
      lower(trim(both '#' from h.tag)) as tag,
      t.author_id,
      t.created_at,
      t.id as topic_id
    from public.forum_topics t
    cross join lateral public.extract_topic_hashtags(t.title, t.body) as h(tag)
    where t.status = 'published'
      and t.author_id is not null
  )
  select author_id
  from hashtag_usage
  where tag = lower(trim(both '#' from p_tag))
  order by created_at asc, topic_id asc
  limit 1;
$$;

create or replace function public.trg_forum_trophies_after_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_forum_trophies(new.author_id);
  return new;
end;
$$;

drop trigger if exists on_forum_reply_trophies on public.forum_replies;
create trigger on_forum_reply_trophies
  after insert on public.forum_replies
  for each row execute function public.trg_forum_trophies_after_reply();

create or replace function public.trg_forum_trophies_after_topic()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or coalesce(old.status, '') is distinct from 'published') then
    perform public.sync_forum_trophies(new.author_id);
  end if;
  return new;
end;
$$;

drop trigger if exists on_forum_topic_trophies on public.forum_topics;
create trigger on_forum_topic_trophies
  after insert or update of status on public.forum_topics
  for each row execute function public.trg_forum_trophies_after_topic();

create or replace function public.trg_forum_trophies_after_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid;
begin
  select author_id into v_author
  from public.forum_replies
  where id = new.reply_id;

  perform public.sync_forum_trophies(v_author);
  return new;
end;
$$;

drop trigger if exists on_forum_reaction_trophies on public.forum_reply_likes;
create trigger on_forum_reaction_trophies
  after insert on public.forum_reply_likes
  for each row execute function public.trg_forum_trophies_after_reaction();

create or replace function public.trg_forum_trophies_after_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topic_author uuid;
  v_pioneer uuid;
begin
  if new.target_type = 'profile' then
    perform public.sync_forum_trophies(new.target_id::uuid);
  elsif new.target_type = 'topic' then
    select author_id into v_topic_author
    from public.forum_topics
    where id = new.target_id;
    perform public.sync_forum_trophies(v_topic_author);
  elsif new.target_type = 'hashtag' then
    v_pioneer := public.forum_hashtag_pioneer_id(new.target_id);
    perform public.sync_forum_trophies(v_pioneer);
  end if;
  return new;
end;
$$;

drop trigger if exists on_forum_follow_trophies on public.follows;
create trigger on_forum_follow_trophies
  after insert on public.follows
  for each row execute function public.trg_forum_trophies_after_follow();

-- También al subir follower_count vía trigger existente.
create or replace function public.handle_profile_follow_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.target_type = 'profile' then
    update public.profiles
    set follower_count = follower_count + 1
    where id::text = new.target_id;
    perform public.sync_forum_trophies(new.target_id::uuid);
  elsif tg_op = 'DELETE' and old.target_type = 'profile' then
    update public.profiles
    set follower_count = greatest(follower_count - 1, 0)
    where id::text = old.target_id;
  end if;
  return coalesce(new, old);
end;
$$;

grant execute on function public.sync_forum_trophies(uuid) to authenticated, anon;
grant execute on function public.sync_profile_trophy_points(uuid) to authenticated, anon;


-- ###########################################################################
-- FILE: forum_trophies_topic_views.sql
-- ###########################################################################

-- Cofradeo · trofeos al registrar visitas en temas
-- Ejecutar después de forum_trophies.sql y topic_views_dedup.sql

create or replace function public.increment_topic_view(
  p_topic_id text,
  p_viewer_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int;
  v_author_id uuid;
begin
  insert into public.topic_views (topic_id, viewer_id, viewed_on)
  values (p_topic_id, p_viewer_id, current_date)
  on conflict (topic_id, viewer_id, viewed_on) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.forum_topics
    set view_count = view_count + 1
    where id = p_topic_id
    returning author_id into v_author_id;

    perform public.sync_forum_trophies(v_author_id);
  end if;
end;
$$;

grant execute on function public.increment_topic_view(text, text) to anon, authenticated;


-- ###########################################################################
-- FILE: forum_trophies_rank_notify.sql
-- ###########################################################################

-- Cofradeo · notificación sorpresa al ascender de rango cofrade
-- Ejecutar después de forum_trophies.sql

create or replace function public.cofrade_rank_level(p_points int)
returns int
language sql
immutable
as $$
  select case
    when coalesce(p_points, 0) >= 163 then 27
    when coalesce(p_points, 0) >= 158 then 26
    when coalesce(p_points, 0) >= 152 then 25
    when coalesce(p_points, 0) >= 147 then 24
    when coalesce(p_points, 0) >= 143 then 23
    when coalesce(p_points, 0) >= 138 then 22
    when coalesce(p_points, 0) >= 132 then 21
    when coalesce(p_points, 0) >= 124 then 20
    when coalesce(p_points, 0) >= 114 then 19
    when coalesce(p_points, 0) >= 104 then 18
    when coalesce(p_points, 0) >= 94 then 17
    when coalesce(p_points, 0) >= 84 then 16
    when coalesce(p_points, 0) >= 74 then 15
    when coalesce(p_points, 0) >= 65 then 14
    when coalesce(p_points, 0) >= 56 then 13
    when coalesce(p_points, 0) >= 48 then 12
    when coalesce(p_points, 0) >= 40 then 11
    when coalesce(p_points, 0) >= 33 then 10
    when coalesce(p_points, 0) >= 27 then 9
    when coalesce(p_points, 0) >= 22 then 8
    when coalesce(p_points, 0) >= 17 then 7
    when coalesce(p_points, 0) >= 13 then 6
    when coalesce(p_points, 0) >= 9 then 5
    when coalesce(p_points, 0) >= 6 then 4
    when coalesce(p_points, 0) >= 3 then 3
    when coalesce(p_points, 0) >= 1 then 2
    else 1
  end;
$$;

create or replace function public.cofrade_rank_title(p_points int)
returns text
language sql
immutable
as $$
  select case public.cofrade_rank_level(p_points)
    when 27 then 'Hermano Mayor'
    when 26 then 'Teniente de Hermano Mayor'
    when 25 then 'Diputado Mayor de Gobierno'
    when 24 then 'Fiscal'
    when 23 then 'Secretario'
    when 22 then 'Mayordomo I'
    when 21 then 'Mayordomo II'
    when 20 then 'Prioste I'
    when 19 then 'Prioste II'
    when 18 then 'Auxiliar de Priostía'
    when 17 then 'Diputado de Juventud'
    when 16 then 'Diputado de Formación'
    when 15 then 'Diputado de Caridad'
    when 14 then 'Diputado de Cultos'
    when 13 then 'Diputado de Tramo'
    when 12 then 'Capataz'
    when 11 then 'Contraguía'
    when 10 then 'Costalero'
    when 9 then 'Nazareno Último Tramo'
    when 8 then 'Nazareno 5.º Tramo'
    when 7 then 'Nazareno 4.º Tramo'
    when 6 then 'Nazareno 3.º Tramo'
    when 5 then 'Nazareno 2.º Tramo'
    when 4 then 'Nazareno 1.º Tramo'
    when 3 then 'Nazareno'
    when 2 then 'Hermano'
    else 'Cofrade de a pie'
  end;
$$;

create or replace function public.sync_profile_trophy_points(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_points int := 0;
  v_points int := 0;
  v_old_level int;
  v_new_level int;
  v_title text;
begin
  if p_user_id is null then
    return;
  end if;

  select coalesce(trophy_points, 0)
  into v_old_points
  from public.profiles
  where id = p_user_id;

  select coalesce(sum(
    case trophy_id
      when 'first_reply' then 1
      when 'replies_10' then 2
      when 'replies_30' then 3
      when 'replies_100' then 5
      when 'first_topic' then 3
      when 'topics_5' then 4
      when 'topics_15' then 8
      when 'topics_40' then 12
      when 'topic_views_100' then 2
      when 'topic_views_500' then 5
      when 'topic_views_2000' then 10
      when 'topic_views_10000' then 15
      when 'reactions_1' then 2
      when 'reactions_25' then 5
      when 'reactions_100' then 10
      when 'reactions_250' then 15
      when 'reactions_500' then 20
      when 'followers_5' then 3
      when 'followers_25' then 8
      when 'followers_100' then 15
      when 'hashtag_followers_5' then 4
      when 'hashtag_followers_25' then 10
      when 'topic_followers_10' then 4
      when 'topic_followers_50' then 8
      else 0
    end
  ), 0)
  into v_points
  from public.profile_trophies
  where user_id = p_user_id;

  v_old_level := public.cofrade_rank_level(v_old_points);
  v_new_level := public.cofrade_rank_level(v_points);

  update public.profiles
  set trophy_points = v_points
  where id = p_user_id;

  if v_new_level > v_old_level then
    perform set_config('row_security', 'off', true);
    v_title := public.cofrade_rank_title(v_points);

    insert into public.notifications (user_id, type, title, subtitle, payload)
    values (
      p_user_id,
      'cofrade_rank_up',
      'Has ascendido a ' || v_title,
      'Enhorabuena, cofrade.',
      jsonb_build_object(
        'route', '/perfil',
        'rankLevel', v_new_level,
        'rankTitle', v_title
      )
    );
  end if;
end;
$$;

grant execute on function public.cofrade_rank_level(int) to authenticated, anon;
grant execute on function public.cofrade_rank_title(int) to authenticated, anon;


-- ###########################################################################
-- FILE: ads.sql
-- ###########################################################################

-- Cofradero · patrocinios nativos internos
-- Ejecutar después de schema.sql.

create table if not exists public.ads (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 80),
  description text not null default '' check (char_length(description) <= 180),
  image_url text,
  sponsor_logo_url text,
  calendar_event_id uuid references public.calendar_events (id) on delete set null,
  sponsor_name text not null default '' check (char_length(sponsor_name) <= 80),
  button_text text not null default 'Ver más' check (char_length(button_text) <= 30),
  target_url text not null,
  placement text not null check (
    placement in (
      'home',
      'forums_top',
      'forums_middle',
      'forums_event',
      'calendar',
      'search',
      'profile',
      'hermandades'
    )
  ),
  priority int not null default 1 check (priority between 1 and 100),
  max_impressions int not null check (max_impressions > 0),
  current_impressions int not null default 0 check (current_impressions >= 0),
  start_date timestamptz not null default now(),
  end_date timestamptz,
  active boolean not null default true,
  forum_id text,
  created_at timestamptz not null default now()
);

alter table public.ads
  add column if not exists sponsor_logo_url text;

alter table public.ads
  add column if not exists calendar_event_id uuid references public.calendar_events (id) on delete set null;

alter table public.ads
  add column if not exists forum_id text;

create index if not exists ads_placement_active_idx
  on public.ads (placement, active, priority desc);

create table if not exists public.ad_impressions (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  viewer_id text not null,
  created_at timestamptz not null default now()
);

create index if not exists ad_impressions_ad_created_idx
  on public.ad_impressions (ad_id, created_at desc);

create index if not exists ad_impressions_viewer_recent_idx
  on public.ad_impressions (ad_id, viewer_id, created_at desc);

create table if not exists public.ad_clicks (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.ads (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  viewer_id text not null,
  created_at timestamptz not null default now()
);

create index if not exists ad_clicks_ad_created_idx
  on public.ad_clicks (ad_id, created_at desc);

alter table public.ads enable row level security;
alter table public.ad_impressions enable row level security;
alter table public.ad_clicks enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ad-assets',
  'ad-assets',
  true,
  4194304,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Assets anuncios lectura publica" on storage.objects;
create policy "Assets anuncios lectura publica"
  on storage.objects for select
  using (bucket_id = 'ad-assets');

drop policy if exists "Staff sube assets anuncios" on storage.objects;
create policy "Staff sube assets anuncios"
  on storage.objects for insert
  with check (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff actualiza assets anuncios" on storage.objects;
create policy "Staff actualiza assets anuncios"
  on storage.objects for update
  using (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  )
  with check (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Staff borra assets anuncios" on storage.objects;
create policy "Staff borra assets anuncios"
  on storage.objects for delete
  using (
    bucket_id = 'ad-assets'
    and public.is_staff_user(auth.uid())
  );

drop policy if exists "Anuncios activos legibles" on public.ads;
create policy "Anuncios activos legibles"
  on public.ads for select
  using (
    active = true
    and start_date <= now()
    and (end_date is null or end_date >= now())
    and current_impressions < max_impressions
  );

drop policy if exists "Staff gestiona anuncios" on public.ads;
create policy "Staff gestiona anuncios"
  on public.ads for all
  using (public.is_staff_user(auth.uid()))
  with check (public.is_staff_user(auth.uid()));

drop policy if exists "Staff lee impresiones" on public.ad_impressions;
create policy "Staff lee impresiones"
  on public.ad_impressions for select
  using (public.is_staff_user(auth.uid()));

drop policy if exists "Staff lee clicks" on public.ad_clicks;
create policy "Staff lee clicks"
  on public.ad_clicks for select
  using (public.is_staff_user(auth.uid()));

create or replace function public.get_ad_for_placement(
  p_placement text,
  p_forum_id text default null
)
returns setof public.ads
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  with eligible as (
    select a.*, sum(a.priority) over () as total_priority
    from public.ads a
    where a.placement = p_placement
      and a.active = true
      and a.start_date <= now()
      and (a.end_date is null or a.end_date >= now())
      and a.current_impressions < a.max_impressions
      and (
        p_forum_id is null
        or a.forum_id is null
        or a.forum_id = p_forum_id
      )
  ),
  pick as (
    select random() * coalesce(max(total_priority), 0) as ticket
    from eligible
  ),
  weighted as (
    select
      e.id,
      e.priority,
      e.created_at,
      sum(e.priority) over (order by e.priority desc, e.created_at asc) as cumulative
    from eligible e
  ),
  picked as (
    select w.id
    from weighted w, pick p
    where w.cumulative >= p.ticket
    order by w.cumulative asc
    limit 1
  )
  select a.*
  from public.ads a
  join picked on picked.id = a.id;
end;
$$;

create or replace function public.register_ad_impression(
  p_ad_id uuid,
  p_viewer_id text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_exists boolean;
begin
  if p_viewer_id is null or length(trim(p_viewer_id)) = 0 then
    raise exception 'viewer_id requerido';
  end if;

  select exists (
    select 1
    from public.ad_impressions
    where ad_id = p_ad_id
      and viewer_id = p_viewer_id
      and created_at >= now() - interval '24 hours'
  )
  into v_exists;

  if v_exists then
    return false;
  end if;

  insert into public.ad_impressions (ad_id, user_id, viewer_id)
  values (p_ad_id, v_user_id, p_viewer_id);

  update public.ads
  set current_impressions = current_impressions + 1
  where id = p_ad_id
    and active = true
    and current_impressions < max_impressions;

  return true;
end;
$$;

create or replace function public.register_ad_click(
  p_ad_id uuid,
  p_viewer_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_viewer_id is null or length(trim(p_viewer_id)) = 0 then
    raise exception 'viewer_id requerido';
  end if;

  insert into public.ad_clicks (ad_id, user_id, viewer_id)
  values (p_ad_id, auth.uid(), p_viewer_id);
end;
$$;

create or replace view public.ad_statistics
with (security_invoker = true)
as
select
  a.id,
  a.title,
  a.sponsor_name,
  a.placement,
  a.priority,
  a.max_impressions,
  a.current_impressions,
  count(distinct i.id)::int as tracked_impressions,
  count(distinct c.id)::int as clicks,
  case
    when count(distinct i.id) = 0 then 0
    else round(
      (count(distinct c.id)::numeric / count(distinct i.id)::numeric) * 100,
      2
    )
  end as ctr
from public.ads a
left join public.ad_impressions i on i.ad_id = a.id
left join public.ad_clicks c on c.ad_id = a.id
group by a.id;

-- Ejemplo de patrocinio superior en Foros:
-- insert into public.ads (
--   title, description, sponsor_name, button_text, target_url,
--   placement, priority, max_impressions
-- ) values (
--   'Costales La Trasera',
--   'Todo para el costalero. Calidad y tradición desde 1998.',
--   'Costales La Trasera',
--   'Visitar tienda',
--   'https://example.com',
--   'forums_top',
--   10,
--   5000
-- );


-- ###########################################################################
-- FILE: ads_forum_targeting.sql
-- ###########################################################################

-- Objetivo por foro en eventos patrocinados y banners de listado (forums_event / forums_middle).
-- Ejecutar en Supabase → SQL Editor.

alter table public.ads
  add column if not exists forum_id text;

create index if not exists ads_placement_forum_active_idx
  on public.ads (placement, forum_id, active, priority desc);

create or replace function public.get_ad_for_placement(
  p_placement text,
  p_forum_id text default null
)
returns setof public.ads
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  with eligible as (
    select a.*, sum(a.priority) over () as total_priority
    from public.ads a
    where a.placement = p_placement
      and a.active = true
      and a.start_date <= now()
      and (a.end_date is null or a.end_date >= now())
      and a.current_impressions < a.max_impressions
      and (
        p_forum_id is null
        or a.forum_id is null
        or a.forum_id = p_forum_id
      )
  ),
  pick as (
    select random() * coalesce(max(total_priority), 0) as ticket
    from eligible
  ),
  weighted as (
    select
      e.id,
      e.priority,
      e.created_at,
      sum(e.priority) over (order by e.priority desc, e.created_at asc) as cumulative
    from eligible e
  ),
  picked as (
    select w.id
    from weighted w, pick p
    where w.cumulative >= p.ticket
    order by w.cumulative asc
    limit 1
  )
  select a.*
  from public.ads a
  join picked on picked.id = a.id;
end;
$$;


-- ###########################################################################
-- FILE: ads_featured_topic.sql
-- ###########################################################################

-- Banner en temas destacados (Cuaresma / Semana Santa / Glorias).
-- Placement: featured_topic · segmentación opcional por topic_id.
-- Ejecutar en Supabase → SQL Editor.

alter table public.ads
  add column if not exists topic_id text;

create index if not exists ads_placement_topic_active_idx
  on public.ads (placement, topic_id, active, priority desc);

alter table public.ads drop constraint if exists ads_placement_check;

alter table public.ads
  add constraint ads_placement_check check (
    placement in (
      'home',
      'forums_top',
      'forums_middle',
      'forums_event',
      'calendar',
      'search',
      'profile',
      'hermandades',
      'featured_topic'
    )
  );

create or replace function public.get_ad_for_placement(
  p_placement text,
  p_forum_id text default null,
  p_topic_id text default null
)
returns setof public.ads
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  with eligible as (
    select a.*, sum(a.priority) over () as total_priority
    from public.ads a
    where a.placement = p_placement
      and a.active = true
      and a.start_date <= now()
      and (a.end_date is null or a.end_date >= now())
      and a.current_impressions < a.max_impressions
      and (
        p_forum_id is null
        or a.forum_id is null
        or a.forum_id = p_forum_id
      )
      and (
        p_topic_id is null
        or a.topic_id is null
        or a.topic_id = p_topic_id
      )
  ),
  pick as (
    select random() * coalesce(max(total_priority), 0) as ticket
    from eligible
  ),
  weighted as (
    select
      e.id,
      e.priority,
      e.created_at,
      sum(e.priority) over (order by e.priority desc, e.created_at asc) as cumulative
    from eligible e
  ),
  picked as (
    select w.id
    from weighted w, pick p
    where w.cumulative >= p.ticket
    order by w.cumulative asc
    limit 1
  )
  select a.*
  from public.ads a
  join picked on picked.id = a.id;
end;
$$;


-- ###########################################################################
-- FILE: ads_forums_event_placement.sql
-- ###########################################################################

-- Añade el placement forums_event (evento patrocinado en listados de foro).
-- Ejecutar en Supabase → SQL Editor.

alter table public.ads drop constraint if exists ads_placement_check;

alter table public.ads
  add constraint ads_placement_check check (
    placement in (
      'home',
      'forums_top',
      'forums_middle',
      'forums_event',
      'calendar',
      'search',
      'profile',
      'hermandades'
    )
  );


-- ###########################################################################
-- FILE: ads_rpc_fix.sql
-- ###########################################################################

-- Corrige get_ad_for_placement cuando la RPC devolvía error 42804
-- (columnas en orden distinto al de public.ads en BDs ya desplegadas).
-- Incluye filtro opcional por foro (forum_id).
-- Ejecutar en Supabase → SQL Editor.

create or replace function public.get_ad_for_placement(
  p_placement text,
  p_forum_id text default null
)
returns setof public.ads
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  with eligible as (
    select a.*, sum(a.priority) over () as total_priority
    from public.ads a
    where a.placement = p_placement
      and a.active = true
      and a.start_date <= now()
      and (a.end_date is null or a.end_date >= now())
      and a.current_impressions < a.max_impressions
      and (
        p_forum_id is null
        or a.forum_id is null
        or a.forum_id = p_forum_id
      )
  ),
  pick as (
    select random() * coalesce(max(total_priority), 0) as ticket
    from eligible
  ),
  weighted as (
    select
      e.id,
      e.priority,
      e.created_at,
      sum(e.priority) over (order by e.priority desc, e.created_at asc) as cumulative
    from eligible e
  ),
  picked as (
    select w.id
    from weighted w, pick p
    where w.cumulative >= p.ticket
    order by w.cumulative asc
    limit 1
  )
  select a.*
  from public.ads a
  join picked on picked.id = a.id;
end;
$$;


-- ###########################################################################
-- FILE: ads_statistics_period.sql
-- ###########################################################################

-- Informe de publicidad por periodo (mes / rango / todo).
-- Ejecutar en Supabase SQL Editor.

create or replace function public.get_ad_statistics(
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns table (
  id uuid,
  title text,
  sponsor_name text,
  placement text,
  priority int,
  max_impressions int,
  current_impressions int,
  tracked_impressions int,
  clicks int,
  ctr numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_staff_user(auth.uid()) then
    raise exception 'Solo personal de Junta';
  end if;

  return query
  select
    a.id,
    a.title,
    a.sponsor_name,
    a.placement,
    a.priority,
    a.max_impressions,
    a.current_impressions,
    count(distinct i.id)::int as tracked_impressions,
    count(distinct c.id)::int as clicks,
    case
      when count(distinct i.id) = 0 then 0::numeric
      else round(
        (count(distinct c.id)::numeric / count(distinct i.id)::numeric) * 100,
        2
      )
    end as ctr
  from public.ads a
  left join public.ad_impressions i
    on i.ad_id = a.id
    and (p_from is null or i.created_at >= p_from)
    and (p_to is null or i.created_at < p_to)
  left join public.ad_clicks c
    on c.ad_id = a.id
    and (p_from is null or c.created_at >= p_from)
    and (p_to is null or c.created_at < p_to)
  group by a.id
  order by tracked_impressions desc, a.sponsor_name, a.title;
end;
$$;

grant execute on function public.get_ad_statistics(timestamptz, timestamptz) to authenticated;


-- ###########################################################################
-- FILE: sponsor_settings.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: sponsor_waitlist.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: finance_sponsor_payments.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: liturgical_countdown.sql
-- ###########################################################################

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


-- ###########################################################################
-- FILE: quiz_daily.sql
-- ###########################################################################

-- Cofradero · Pregunta en vivo (quiz)
-- Ejecutar después de roles_v2.sql y notification_social.sql / calendar_notify.sql
-- Idempotente.

-- Preferencia de avisos
alter table public.notification_preferences
  add column if not exists notify_quiz boolean not null default true;

create or replace function public.notify_pref_enabled(p_user_id uuid, p_pref text)
returns boolean
language sql
stable
set search_path = public
as $$
  select case p_pref
    when 'hashtags' then coalesce(
      (select notify_hashtags from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'profiles' then coalesce(
      (select notify_profiles from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'topics' then coalesce(
      (select notify_topics from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'mentions' then coalesce(
      (select notify_mentions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'followers' then coalesce(
      (select notify_followers from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'reactions' then coalesce(
      (select notify_reactions from public.notification_preferences where user_id = p_user_id),
      true
    )
    when 'calendar' then coalesce(
      (select notify_calendar from public.notification_preferences where user_id = p_user_id),
      false
    )
    when 'quiz' then coalesce(
      (select notify_quiz from public.notification_preferences where user_id = p_user_id),
      true
    )
    else true
  end;
$$;

-- Preguntas propuestas / aprobadas
create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  prompt text not null check (char_length(btrim(prompt)) between 3 and 280),
  image_url text,
  option_a text not null check (char_length(btrim(option_a)) between 1 and 120),
  option_b text not null check (char_length(btrim(option_b)) between 1 and 120),
  option_c text not null check (char_length(btrim(option_c)) between 1 and 120),
  option_d text not null check (char_length(btrim(option_d)) between 1 and 120),
  correct_option text not null check (correct_option in ('a', 'b', 'c', 'd')),
  explanation text check (
    explanation is null or char_length(btrim(explanation)) between 3 and 280
  ),
  status text not null default 'pending_review'
    check (status in ('draft', 'pending_review', 'approved', 'rejected')),
  created_by uuid references public.profiles (id) on delete set null,
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists quiz_questions_status_idx
  on public.quiz_questions (status, created_at desc);

-- Rondas en vivo
create table if not exists public.quiz_rounds (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.quiz_questions (id) on delete restrict,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'live', 'closed')),
  launched_at timestamptz,
  closes_at timestamptz,
  answer_seconds int not null default 15 check (answer_seconds between 5 and 60),
  open_minutes int not null default 1440 check (open_minutes between 1 and 2880),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists quiz_rounds_status_idx
  on public.quiz_rounds (status, launched_at desc);

-- Una sola ronda live a la vez (parcial)
create unique index if not exists quiz_rounds_one_live_idx
  on public.quiz_rounds (status)
  where status = 'live';

-- Respuestas de usuarios
create table if not exists public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.quiz_rounds (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  selected_option text check (
    selected_option is null or selected_option in ('a', 'b', 'c', 'd')
  ),
  is_correct boolean,
  opened_at timestamptz not null default now(),
  answered_at timestamptz,
  score int not null default 0,
  created_at timestamptz not null default now(),
  unique (round_id, user_id)
);

create index if not exists quiz_answers_user_idx
  on public.quiz_answers (user_id, created_at desc);

create index if not exists quiz_answers_round_score_idx
  on public.quiz_answers (round_id, score desc);

-- Ranking mensual acumulado
create table if not exists public.quiz_monthly_scores (
  user_id uuid not null references public.profiles (id) on delete cascade,
  year_month text not null check (year_month ~ '^[0-9]{4}-[0-9]{2}$'),
  points int not null default 0,
  answers_count int not null default 0,
  correct_count int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, year_month)
);

create index if not exists quiz_monthly_scores_rank_idx
  on public.quiz_monthly_scores (year_month, points desc);

alter table public.quiz_questions enable row level security;
alter table public.quiz_rounds enable row level security;
alter table public.quiz_answers enable row level security;
alter table public.quiz_monthly_scores enable row level security;

-- Junta ve / gestiona preguntas
drop policy if exists "Junta lee preguntas quiz" on public.quiz_questions;
create policy "Junta lee preguntas quiz"
  on public.quiz_questions for select
  using (public.is_junta_member(auth.uid()));

drop policy if exists "Junta crea preguntas quiz" on public.quiz_questions;
create policy "Junta crea preguntas quiz"
  on public.quiz_questions for insert
  with check (
    public.is_junta_member(auth.uid())
    and created_by = auth.uid()
  );

drop policy if exists "Admin actualiza preguntas quiz" on public.quiz_questions;
create policy "Admin actualiza preguntas quiz"
  on public.quiz_questions for update
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

drop policy if exists "Creador edita pregunta pendiente quiz" on public.quiz_questions;
create policy "Creador edita pregunta pendiente quiz"
  on public.quiz_questions for update
  using (
    created_by = auth.uid()
    and status = 'pending_review'
  )
  with check (
    created_by = auth.uid()
    and status = 'pending_review'
  );

-- Rondas: junta lee; admin escribe; público autenticado lee live/closed (sin join a correct)
drop policy if exists "Usuarios leen rondas quiz" on public.quiz_rounds;
create policy "Usuarios leen rondas quiz"
  on public.quiz_rounds for select
  using (
    status in ('live', 'closed')
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Admin gestiona rondas quiz" on public.quiz_rounds;
create policy "Admin gestiona rondas quiz"
  on public.quiz_rounds for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

-- Respuestas: cada uno las suyas; junta puede leer
drop policy if exists "Usuario gestiona su respuesta quiz" on public.quiz_answers;
create policy "Usuario gestiona su respuesta quiz"
  on public.quiz_answers for select
  using (
    user_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Usuario inserta su respuesta quiz" on public.quiz_answers;
create policy "Usuario inserta su respuesta quiz"
  on public.quiz_answers for insert
  with check (user_id = auth.uid());

drop policy if exists "Usuario actualiza su respuesta quiz" on public.quiz_answers;
create policy "Usuario actualiza su respuesta quiz"
  on public.quiz_answers for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Ranking mensual: lectura pública autenticada
drop policy if exists "Usuarios leen ranking quiz" on public.quiz_monthly_scores;
create policy "Usuarios leen ranking quiz"
  on public.quiz_monthly_scores for select
  using (auth.uid() is not null);

-- Storage bucket (crear en Dashboard si no existe): quiz-images, public read

-- Cierra rondas caducadas
create or replace function public.quiz_close_expired_rounds()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.quiz_rounds
  set status = 'closed'
  where status = 'live'
    and closes_at is not null
    and closes_at <= now();
end;
$$;

-- Lanzar ronda desde pregunta aprobada
create or replace function public.quiz_launch_round(p_question_id uuid)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q public.quiz_questions;
  v_round public.quiz_rounds;
  v_closes timestamptz;
  v_open int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede lanzar la pregunta';
  end if;

  perform public.quiz_close_expired_rounds();

  if exists (select 1 from public.quiz_rounds where status = 'live') then
    raise exception 'Ya hay una pregunta en curso';
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    raise exception 'Pregunta no encontrada';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'La pregunta debe estar aprobada';
  end if;

  -- Fin del día actual (Europe/Madrid)
  v_closes := (
    (timezone('Europe/Madrid', now())::date + 1)::timestamp
  ) at time zone 'Europe/Madrid';

  v_open := greatest(
    1,
    ceil(extract(epoch from (v_closes - now())) / 60.0)::int
  );

  insert into public.quiz_rounds (
    question_id, status, launched_at, closes_at, answer_seconds, open_minutes, created_by
  ) values (
    p_question_id, 'live', now(), v_closes, 15, v_open, auth.uid()
  )
  returning * into v_round;

  return v_round;
end;
$$;

revoke all on function public.quiz_launch_round(uuid) from public;
grant execute on function public.quiz_launch_round(uuid) to authenticated;

-- Payload de juego sin spoiler de respuesta
create or replace function public.quiz_get_live_payload()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_answer public.quiz_answers;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round
  from public.quiz_rounds
  where status = 'live'
  order by launched_at desc
  limit 1;

  if v_round.id is null then
    return jsonb_build_object('state', 'idle');
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;
  select * into v_answer
  from public.quiz_answers
  where round_id = v_round.id and user_id = v_uid;

  return jsonb_build_object(
    'state', case when v_answer.answered_at is not null then 'answered' else 'live' end,
    'round', jsonb_build_object(
      'id', v_round.id,
      'launchedAt', v_round.launched_at,
      'closesAt', v_round.closes_at,
      'answerSeconds', v_round.answer_seconds
    ),
    'question', jsonb_build_object(
      'id', v_q.id,
      'prompt', v_q.prompt,
      'imageUrl', v_q.image_url,
      'optionA', v_q.option_a,
      'optionB', v_q.option_b,
      'optionC', v_q.option_c,
      'optionD', v_q.option_d,
      'explanation', case
        when v_answer.answered_at is not null then v_q.explanation
        else null
      end
    ),
    'answer', case
      when v_answer.id is null then null
      else jsonb_build_object(
        'openedAt', v_answer.opened_at,
        'answeredAt', v_answer.answered_at,
        'selectedOption', v_answer.selected_option,
        'isCorrect', v_answer.is_correct,
        'score', v_answer.score,
        'correctOption', case
          when v_answer.answered_at is not null then v_q.correct_option
          else null
        end
      )
    end
  );
end;
$$;

revoke all on function public.quiz_get_live_payload() from public;
grant execute on function public.quiz_get_live_payload() to authenticated;

-- Abrir cronómetro personal
create or replace function public.quiz_open_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round from public.quiz_rounds where id = p_round_id;
  if v_round.id is null or v_round.status <> 'live' then
    raise exception 'La pregunta no está disponible';
  end if;
  if v_round.closes_at is not null and v_round.closes_at <= now() then
    raise exception 'La ronda ha cerrado';
  end if;

  insert into public.quiz_answers (round_id, user_id, opened_at)
  values (p_round_id, v_uid, now())
  on conflict (round_id, user_id) do nothing;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid;

  if v_answer.answered_at is not null then
    raise exception 'Ya has respondido esta pregunta';
  end if;

  return jsonb_build_object(
    'openedAt', v_answer.opened_at,
    'answerSeconds', v_round.answer_seconds,
    'serverNow', now()
  );
end;
$$;

revoke all on function public.quiz_open_round(uuid) from public;
grant execute on function public.quiz_open_round(uuid) to authenticated;

-- Enviar respuesta + score
create or replace function public.quiz_submit_answer(
  p_round_id uuid,
  p_option text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
  v_correct boolean;
  v_score int;
  v_entry_bonus numeric;
  v_timer_bonus numeric;
  v_elapsed_entry numeric;
  v_elapsed_answer numeric;
  v_remaining numeric;
  v_month text;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if p_option is null or p_option not in ('a', 'b', 'c', 'd') then
    raise exception 'Opción inválida';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round from public.quiz_rounds where id = p_round_id for update;
  if v_round.id is null or v_round.status <> 'live' then
    raise exception 'La pregunta no está disponible';
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid
  for update;

  if v_answer.id is null then
    insert into public.quiz_answers (round_id, user_id, opened_at)
    values (p_round_id, v_uid, now())
    returning * into v_answer;
  end if;

  if v_answer.answered_at is not null then
    raise exception 'Ya has respondido esta pregunta';
  end if;

  v_elapsed_entry := extract(epoch from (v_answer.opened_at - v_round.launched_at));
  if v_elapsed_entry < 0 then
    v_elapsed_entry := 0;
  end if;
  -- Bonus llegada: 50 → 0 en 30 minutos
  v_entry_bonus := greatest(0, 50 * (1 - least(v_elapsed_entry, 1800) / 1800.0));

  v_elapsed_answer := extract(epoch from (now() - v_answer.opened_at));
  v_remaining := greatest(0, v_round.answer_seconds - v_elapsed_answer);
  v_timer_bonus := (v_remaining / v_round.answer_seconds::numeric) * 50;

  v_correct := (p_option = v_q.correct_option);

  if v_elapsed_answer > v_round.answer_seconds + 1.5 then
    -- Timeout: cuenta como fallo
    v_correct := false;
    v_score := -40;
  elsif v_correct then
    v_score := round(100 + v_entry_bonus + v_timer_bonus)::int;
  else
    v_score := -40;
  end if;

  update public.quiz_answers
  set
    selected_option = p_option,
    is_correct = v_correct,
    answered_at = now(),
    score = v_score
  where id = v_answer.id
  returning * into v_answer;

  v_month := to_char(timezone('Europe/Madrid', now()), 'YYYY-MM');

  insert into public.quiz_monthly_scores as s (
    user_id, year_month, points, answers_count, correct_count, updated_at
  ) values (
    v_uid,
    v_month,
    v_score,
    1,
    case when v_correct then 1 else 0 end,
    now()
  )
  on conflict (user_id, year_month) do update set
    points = s.points + excluded.points,
    answers_count = s.answers_count + 1,
    correct_count = s.correct_count + excluded.correct_count,
    updated_at = now();

  return jsonb_build_object(
    'isCorrect', v_correct,
    'score', v_score,
    'correctOption', v_q.correct_option,
    'explanation', v_q.explanation,
    'selectedOption', p_option
  );
end;
$$;

revoke all on function public.quiz_submit_answer(uuid, text) from public;
grant execute on function public.quiz_submit_answer(uuid, text) to authenticated;

-- Ranking del mes
create or replace function public.quiz_monthly_leaderboard(p_year_month text default null)
returns table (
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  points int,
  answers_count int,
  correct_count int,
  rank bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month text := coalesce(
    p_year_month,
    to_char(timezone('Europe/Madrid', now()), 'YYYY-MM')
  );
begin
  return query
  select
    s.user_id,
    p.handle,
    p.display_name,
    p.avatar_url,
    s.points,
    s.answers_count,
    s.correct_count,
    rank() over (order by s.points desc, s.correct_count desc, s.updated_at asc)
  from public.quiz_monthly_scores s
  join public.profiles p on p.id = s.user_id
  where s.year_month = v_month
    and p.suspended_at is null
  order by s.points desc, s.correct_count desc, s.updated_at asc
  limit 100;
end;
$$;

revoke all on function public.quiz_monthly_leaderboard(text) from public;
grant execute on function public.quiz_monthly_leaderboard(text) to authenticated;

-- Notificar al lanzar
create or replace function public.notify_users_on_quiz_live()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prompt text;
begin
  if new.status <> 'live' then
    return new;
  end if;
  if tg_op = 'UPDATE' and coalesce(old.status, '') = 'live' then
    return new;
  end if;

  perform set_config('row_security', 'off', true);

  select left(prompt, 80) into v_prompt
  from public.quiz_questions
  where id = new.question_id;

  insert into public.notifications (user_id, type, title, subtitle, payload)
  select
    p.id,
    'quiz',
    '¡Pregunta en vivo!',
    coalesce(v_prompt, 'Tienes 15 segundos para responder'),
    jsonb_build_object(
      'route', '/quiz',
      'roundId', new.id::text
    )
  from public.profiles p
  where p.suspended_at is null
    and public.notify_pref_enabled(p.id, 'quiz');

  return new;
end;
$$;

drop trigger if exists on_quiz_round_live_notify on public.quiz_rounds;
create trigger on_quiz_round_live_notify
  after insert or update of status on public.quiz_rounds
  for each row execute function public.notify_users_on_quiz_live();


-- ###########################################################################
-- FILE: quiz_authors.sql
-- ###########################################################################

-- Cofradero · quién puede proponer preguntas del quiz
-- Ejecutar después de quiz_daily.sql y roles_v2.sql
-- Idempotente.

create table if not exists public.quiz_authors (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  granted_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.quiz_authors enable row level security;

drop policy if exists "Junta lee autores quiz" on public.quiz_authors;
create policy "Junta lee autores quiz"
  on public.quiz_authors for select
  using (
    public.is_admin_user(auth.uid())
    or profile_id = auth.uid()
  );

drop policy if exists "Admin gestiona autores quiz" on public.quiz_authors;
create policy "Admin gestiona autores quiz"
  on public.quiz_authors for all
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

create or replace function public.can_create_quiz_question(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin_user(p_user_id)
    or exists (
      select 1
      from public.quiz_authors qa
      where qa.profile_id = p_user_id
    );
$$;

-- Sustituye políticas de preguntas: solo autores autorizados (o admin)
drop policy if exists "Junta lee preguntas quiz" on public.quiz_questions;
drop policy if exists "Autores y admin leen preguntas quiz" on public.quiz_questions;
create policy "Autores y admin leen preguntas quiz"
  on public.quiz_questions for select
  using (public.can_create_quiz_question(auth.uid()));

drop policy if exists "Junta crea preguntas quiz" on public.quiz_questions;
drop policy if exists "Autores crean preguntas quiz" on public.quiz_questions;
create policy "Autores crean preguntas quiz"
  on public.quiz_questions for insert
  with check (
    public.can_create_quiz_question(auth.uid())
    and created_by = auth.uid()
  );

-- Rondas: autores también pueden leer (panel Junta)
drop policy if exists "Usuarios leen rondas quiz" on public.quiz_rounds;
create policy "Usuarios leen rondas quiz"
  on public.quiz_rounds for select
  using (
    status in ('live', 'closed')
    or public.can_create_quiz_question(auth.uid())
  );

drop policy if exists "Usuario gestiona su respuesta quiz" on public.quiz_answers;
create policy "Usuario gestiona su respuesta quiz"
  on public.quiz_answers for select
  using (
    user_id = auth.uid()
    or public.can_create_quiz_question(auth.uid())
  );


-- ###########################################################################
-- FILE: quiz_fixes.sql
-- ###########################################################################

-- Cofradero · cerrar ronda en vivo (admin) + políticas storage quiz-images
-- Ejecutar después de quiz_daily.sql
--
-- Si la app dice «Ya hay una pregunta en curso» y el cronómetro va a 0 s,
-- desatasca YA con:
--   update public.quiz_rounds set status = 'closed' where status = 'live';

create or replace function public.quiz_close_live_round()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede cerrar la ronda';
  end if;

  update public.quiz_rounds
  set status = 'closed'
  where status = 'live';

  get diagnostics v_n = row_count;

  return jsonb_build_object('closed', v_n);
end;
$$;

revoke all on function public.quiz_close_live_round() from public;
grant execute on function public.quiz_close_live_round() to authenticated;

-- Lanzar: si p_force, cierra la live anterior
create or replace function public.quiz_launch_round(
  p_question_id uuid,
  p_force boolean default false
)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q public.quiz_questions;
  v_round public.quiz_rounds;
  v_closes timestamptz;
  v_open int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede lanzar la pregunta';
  end if;

  perform public.quiz_close_expired_rounds();

  if exists (select 1 from public.quiz_rounds where status = 'live') then
    if coalesce(p_force, false) then
      update public.quiz_rounds set status = 'closed' where status = 'live';
    else
      raise exception 'Ya hay una pregunta en curso';
    end if;
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    raise exception 'Pregunta no encontrada';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'La pregunta debe estar aprobada';
  end if;

  -- Fin del día actual (Europe/Madrid)
  v_closes := (
    (timezone('Europe/Madrid', now())::date + 1)::timestamp
  ) at time zone 'Europe/Madrid';

  v_open := greatest(
    1,
    ceil(extract(epoch from (v_closes - now())) / 60.0)::int
  );

  insert into public.quiz_rounds (
    question_id, status, launched_at, closes_at, answer_seconds, open_minutes, created_by
  ) values (
    p_question_id, 'live', now(), v_closes, 15, v_open, auth.uid()
  )
  returning * into v_round;

  return v_round;
end;
$$;

revoke all on function public.quiz_launch_round(uuid, boolean) from public;
grant execute on function public.quiz_launch_round(uuid, boolean) to authenticated;

-- Mantener overload de 1 arg (compat)
create or replace function public.quiz_launch_round(p_question_id uuid)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.quiz_launch_round(p_question_id, false);
end;
$$;

revoke all on function public.quiz_launch_round(uuid) from public;
grant execute on function public.quiz_launch_round(uuid) to authenticated;

-- Bucket público de imágenes (idempotente vía API Dashboard si falla)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quiz-images',
  'quiz-images',
  true,
  524288,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Quiz images public read" on storage.objects;
create policy "Quiz images public read"
  on storage.objects for select
  using (bucket_id = 'quiz-images');

drop policy if exists "Quiz authors upload images" on storage.objects;
create policy "Quiz authors upload images"
  on storage.objects for insert
  with check (
    bucket_id = 'quiz-images'
    and auth.uid() is not null
    and public.can_create_quiz_question(auth.uid())
  );

drop policy if exists "Quiz authors update images" on storage.objects;
create policy "Quiz authors update images"
  on storage.objects for update
  using (
    bucket_id = 'quiz-images'
    and public.can_create_quiz_question(auth.uid())
  )
  with check (
    bucket_id = 'quiz-images'
    and public.can_create_quiz_question(auth.uid())
  );


-- ###########################################################################
-- FILE: quiz_audio.sql
-- ###########################################################################

-- Cofradero · audio opcional en preguntas del quiz
-- Ejecutar en SQL Editor después de quiz_daily.sql / quiz_fixes.sql

alter table public.quiz_questions
  add column if not exists audio_url text;

-- Payload en vivo: incluir audioUrl (sin spoiler)
create or replace function public.quiz_get_live_payload()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_answer public.quiz_answers;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round
  from public.quiz_rounds
  where status = 'live'
  order by launched_at desc
  limit 1;

  if v_round.id is null then
    return jsonb_build_object('state', 'idle');
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;
  select * into v_answer
  from public.quiz_answers
  where round_id = v_round.id and user_id = v_uid;

  return jsonb_build_object(
    'state', case when v_answer.answered_at is not null then 'answered' else 'live' end,
    'round', jsonb_build_object(
      'id', v_round.id,
      'launchedAt', v_round.launched_at,
      'closesAt', v_round.closes_at,
      'answerSeconds', v_round.answer_seconds
    ),
    'question', jsonb_build_object(
      'id', v_q.id,
      'prompt', v_q.prompt,
      'imageUrl', v_q.image_url,
      'audioUrl', v_q.audio_url,
      'optionA', v_q.option_a,
      'optionB', v_q.option_b,
      'optionC', v_q.option_c,
      'optionD', v_q.option_d,
      'explanation', case
        when v_answer.answered_at is not null then v_q.explanation
        else null
      end
    ),
    'answer', case
      when v_answer.id is null then null
      else jsonb_build_object(
        'openedAt', v_answer.opened_at,
        'answeredAt', v_answer.answered_at,
        'selectedOption', v_answer.selected_option,
        'isCorrect', v_answer.is_correct,
        'score', v_answer.score,
        'correctOption', case
          when v_answer.answered_at is not null then v_q.correct_option
          else null
        end
      )
    end
  );
end;
$$;

revoke all on function public.quiz_get_live_payload() from public;
grant execute on function public.quiz_get_live_payload() to authenticated;

-- Bucket público de audio (~1 MB, ~15–20 s)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quiz-audio',
  'quiz-audio',
  true,
  1048576,
  array[
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/wav',
    'audio/x-wav',
    'audio/x-m4a',
    'audio/m4a',
    'audio/mp3'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Quiz audio public read" on storage.objects;
create policy "Quiz audio public read"
  on storage.objects for select
  using (bucket_id = 'quiz-audio');

drop policy if exists "Quiz authors upload audio" on storage.objects;
create policy "Quiz authors upload audio"
  on storage.objects for insert
  with check (
    bucket_id = 'quiz-audio'
    and auth.uid() is not null
    and public.can_create_quiz_question(auth.uid())
  );

drop policy if exists "Quiz authors update audio" on storage.objects;
create policy "Quiz authors update audio"
  on storage.objects for update
  using (
    bucket_id = 'quiz-audio'
    and public.can_create_quiz_question(auth.uid())
  )
  with check (
    bucket_id = 'quiz-audio'
    and public.can_create_quiz_question(auth.uid())
  );


-- ###########################################################################
-- FILE: quiz_forfeit.sql
-- ###########################################################################

-- Cofradero · abandonar pregunta = fallo (si sales tras Empezar)
-- Ejecutar en SQL Editor después de quiz_daily.sql

create or replace function public.quiz_forfeit_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.quiz_rounds;
  v_q public.quiz_questions;
  v_uid uuid := auth.uid();
  v_answer public.quiz_answers;
  v_month text;
  v_score int := -40;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  perform public.quiz_close_expired_rounds();

  select * into v_round from public.quiz_rounds where id = p_round_id for update;
  if v_round.id is null then
    raise exception 'Ronda no encontrada';
  end if;

  select * into v_q from public.quiz_questions where id = v_round.question_id;

  select * into v_answer
  from public.quiz_answers
  where round_id = p_round_id and user_id = v_uid
  for update;

  -- Sin haber empezado: no hay nada que abandonar.
  if v_answer.id is null then
    return jsonb_build_object(
      'forfeited', false,
      'reason', 'not_opened'
    );
  end if;

  -- Ya respondió: idempotente.
  if v_answer.answered_at is not null then
    return jsonb_build_object(
      'forfeited', false,
      'reason', 'already_answered',
      'isCorrect', v_answer.is_correct,
      'score', v_answer.score,
      'correctOption', v_q.correct_option,
      'selectedOption', v_answer.selected_option,
      'explanation', v_q.explanation
    );
  end if;

  update public.quiz_answers
  set
    -- Opción distinta de la correcta (abandono; no cuenta como acierto).
    selected_option = case
      when v_q.correct_option = 'a' then 'b'
      else 'a'
    end,
    is_correct = false,
    answered_at = now(),
    score = v_score
  where id = v_answer.id
  returning * into v_answer;

  v_month := to_char(timezone('Europe/Madrid', now()), 'YYYY-MM');

  insert into public.quiz_monthly_scores as s (
    user_id, year_month, points, answers_count, correct_count, updated_at
  ) values (
    v_uid,
    v_month,
    v_score,
    1,
    0,
    now()
  )
  on conflict (user_id, year_month) do update set
    points = s.points + excluded.points,
    answers_count = s.answers_count + 1,
    updated_at = now();

  return jsonb_build_object(
    'forfeited', true,
    'isCorrect', false,
    'score', v_score,
    'correctOption', v_q.correct_option,
    'selectedOption', v_answer.selected_option,
    'explanation', v_q.explanation
  );
end;
$$;

revoke all on function public.quiz_forfeit_round(uuid) from public;
grant execute on function public.quiz_forfeit_round(uuid) to authenticated;


-- ###########################################################################
-- FILE: quiz_day_long_rounds.sql
-- ###########################################################################

-- Cofradero · ronda en vivo hasta medianoche del día actual (Europe/Madrid)
-- Ejecutar en SQL Editor después de quiz_daily.sql / quiz_fixes.sql
--
-- No son 24 h desde el lanzamiento: cierra a las 00:00 (inicio del día siguiente).

alter table public.quiz_rounds
  drop constraint if exists quiz_rounds_open_minutes_check;

alter table public.quiz_rounds
  alter column open_minutes set default 1440;

alter table public.quiz_rounds
  add constraint quiz_rounds_open_minutes_check
  check (open_minutes between 1 and 2880);

-- Ronda live actual: cierra a medianoche de hoy (Madrid)
update public.quiz_rounds
set
  closes_at = (
    (timezone('Europe/Madrid', now())::date + 1)::timestamp
  ) at time zone 'Europe/Madrid',
  open_minutes = greatest(
    1,
    ceil(
      extract(
        epoch from (
          ((timezone('Europe/Madrid', now())::date + 1)::timestamp
            at time zone 'Europe/Madrid')
          - coalesce(launched_at, now())
        )
      ) / 60.0
    )::int
  )
where status = 'live';

-- Lanzar: abierta hasta fin del día (Madrid); si p_force, cierra la live anterior
create or replace function public.quiz_launch_round(
  p_question_id uuid,
  p_force boolean default false
)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q public.quiz_questions;
  v_round public.quiz_rounds;
  v_closes timestamptz;
  v_open int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin puede lanzar la pregunta';
  end if;

  perform public.quiz_close_expired_rounds();

  if exists (select 1 from public.quiz_rounds where status = 'live') then
    if coalesce(p_force, false) then
      update public.quiz_rounds set status = 'closed' where status = 'live';
    else
      raise exception 'Ya hay una pregunta en curso';
    end if;
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    raise exception 'Pregunta no encontrada';
  end if;
  if v_q.status <> 'approved' then
    raise exception 'La pregunta debe estar aprobada';
  end if;

  -- 00:00 del día siguiente en Europe/Madrid = fin del día actual
  v_closes := (
    (timezone('Europe/Madrid', now())::date + 1)::timestamp
  ) at time zone 'Europe/Madrid';

  v_open := greatest(
    1,
    ceil(extract(epoch from (v_closes - now())) / 60.0)::int
  );

  insert into public.quiz_rounds (
    question_id, status, launched_at, closes_at, answer_seconds, open_minutes, created_by
  ) values (
    p_question_id, 'live', now(), v_closes, 15, v_open, auth.uid()
  )
  returning * into v_round;

  return v_round;
end;
$$;

revoke all on function public.quiz_launch_round(uuid, boolean) from public;
grant execute on function public.quiz_launch_round(uuid, boolean) to authenticated;

create or replace function public.quiz_launch_round(p_question_id uuid)
returns public.quiz_rounds
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.quiz_launch_round(p_question_id, false);
end;
$$;

revoke all on function public.quiz_launch_round(uuid) from public;
grant execute on function public.quiz_launch_round(uuid) to authenticated;


-- ###########################################################################
-- FILE: quiz_ranking_views.sql
-- ###########################################################################

-- Cofradero · ranking mensual escalable (cerca de mí / top / por encima / abajo)
-- Ejecutar en SQL Editor después de quiz_daily.sql

create or replace function public.quiz_monthly_ranking_bundle(
  p_year_month text default null,
  p_mode text default 'around',
  p_limit int default 40
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month text := coalesce(
    p_year_month,
    to_char(timezone('Europe/Madrid', now()), 'YYYY-MM')
  );
  v_mode text := lower(coalesce(nullif(btrim(p_mode), ''), 'around'));
  v_limit int := least(greatest(coalesce(p_limit, 40), 5), 100);
  v_uid uuid := auth.uid();
  v_half int;
  v_my_rank bigint;
  v_total int;
  v_me jsonb;
  v_entries jsonb;
  v_lo bigint;
  v_hi bigint;
begin
  if v_uid is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if v_mode not in ('top', 'around', 'above', 'below') then
    v_mode := 'around';
  end if;

  v_half := greatest(v_limit / 2, 5);

  select count(*)::int into v_total
  from public.quiz_monthly_scores s
  join public.profiles p on p.id = s.user_id
  where s.year_month = v_month
    and p.suspended_at is null;

  with ranked as (
    select
      s.user_id,
      p.handle,
      p.display_name,
      p.avatar_url,
      s.points,
      s.answers_count,
      s.correct_count,
      rank() over (
        order by s.points desc, s.correct_count desc, s.updated_at asc
      ) as rnk
    from public.quiz_monthly_scores s
    join public.profiles p on p.id = s.user_id
    where s.year_month = v_month
      and p.suspended_at is null
  )
  select
    jsonb_build_object(
      'userId', r.user_id,
      'handle', r.handle,
      'displayName', r.display_name,
      'avatarUrl', r.avatar_url,
      'points', r.points,
      'answersCount', r.answers_count,
      'correctCount', r.correct_count,
      'rank', r.rnk
    ),
    r.rnk
  into v_me, v_my_rank
  from ranked r
  where r.user_id = v_uid;

  if v_mode = 'around' and v_my_rank is null then
    v_mode := 'top';
  end if;

  if v_mode = 'top' then
    v_lo := 1;
    v_hi := v_limit;
  elsif v_mode = 'around' then
    v_lo := greatest(1, v_my_rank - v_half);
    v_hi := v_my_rank + v_half;
  elsif v_mode = 'above' then
    if v_my_rank is null or v_my_rank <= 1 then
      v_lo := 1;
      v_hi := 0; -- vacío
    else
      v_lo := greatest(1, v_my_rank - v_limit);
      v_hi := v_my_rank - 1;
    end if;
  else -- below
    if v_my_rank is null then
      v_lo := 1;
      v_hi := 0;
    else
      v_lo := v_my_rank + 1;
      v_hi := v_my_rank + v_limit;
    end if;
  end if;

  with ranked as (
    select
      s.user_id,
      p.handle,
      p.display_name,
      p.avatar_url,
      s.points,
      s.answers_count,
      s.correct_count,
      rank() over (
        order by s.points desc, s.correct_count desc, s.updated_at asc
      ) as rnk
    from public.quiz_monthly_scores s
    join public.profiles p on p.id = s.user_id
    where s.year_month = v_month
      and p.suspended_at is null
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'userId', r.user_id,
        'handle', r.handle,
        'displayName', r.display_name,
        'avatarUrl', r.avatar_url,
        'points', r.points,
        'answersCount', r.answers_count,
        'correctCount', r.correct_count,
        'rank', r.rnk
      )
      order by r.rnk
    ),
    '[]'::jsonb
  )
  into v_entries
  from ranked r
  where r.rnk between v_lo and v_hi;

  return jsonb_build_object(
    'yearMonth', v_month,
    'mode', v_mode,
    'totalPlayers', coalesce(v_total, 0),
    'me', v_me,
    'entries', coalesce(v_entries, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.quiz_monthly_ranking_bundle(text, text, int) from public;
grant execute on function public.quiz_monthly_ranking_bundle(text, text, int) to authenticated;


-- ###########################################################################
-- FILE: quiz_season_cleanup.sql
-- ###########################################################################

-- Cofradero · borrar preguntas (+ media) y config Temporada cofrade
-- Ejecutar tras quiz_daily / quiz_fixes / quiz_audio

-- Temporada cofrade (visible en idle del quiz)
insert into public.app_config (key, value)
values
  ('quiz_season_starts_on', ''),
  ('quiz_season_message', ''),
  -- Acceso público a Pregunta en vivo (FAB + rutas /quiz)
  ('quiz_live_visible', 'true')
on conflict (key) do nothing;

-- Admin puede borrar preguntas
drop policy if exists "Admin borra preguntas quiz" on public.quiz_questions;
create policy "Admin borra preguntas quiz"
  on public.quiz_questions for delete
  using (public.is_admin_user(auth.uid()));

-- Storage: admin borra media del quiz
drop policy if exists "Admin delete quiz images" on storage.objects;
create policy "Admin delete quiz images"
  on storage.objects for delete
  using (
    bucket_id = 'quiz-images'
    and public.is_admin_user(auth.uid())
  );

drop policy if exists "Admin delete quiz audio" on storage.objects;
create policy "Admin delete quiz audio"
  on storage.objects for delete
  using (
    bucket_id = 'quiz-audio'
    and public.is_admin_user(auth.uid())
  );

create or replace function public.quiz_delete_question_media(p_question_id uuid)
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
begin
  delete from storage.objects
  where bucket_id in ('quiz-images', 'quiz-audio')
    and (
      name like (p_question_id::text || '/%')
      or name = p_question_id::text
    );
end;
$$;

-- Borra una pregunta (no si está en vivo). Ranking mensual no se toca.
create or replace function public.quiz_delete_question(p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_q public.quiz_questions;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  select * into v_q from public.quiz_questions where id = p_question_id;
  if v_q.id is null then
    return jsonb_build_object('deleted', false, 'reason', 'not_found');
  end if;

  if exists (
    select 1
    from public.quiz_rounds r
    where r.question_id = p_question_id
      and r.status = 'live'
  ) then
    raise exception 'No se puede borrar una pregunta en vivo. Cierra la ronda primero.';
  end if;

  -- Respuestas caen en cascada al borrar rondas.
  delete from public.quiz_rounds where question_id = p_question_id;
  perform public.quiz_delete_question_media(p_question_id);
  delete from public.quiz_questions where id = p_question_id;

  return jsonb_build_object('deleted', true, 'id', p_question_id);
end;
$$;

revoke all on function public.quiz_delete_question(uuid) from public;
grant execute on function public.quiz_delete_question(uuid) to authenticated;

revoke all on function public.quiz_delete_question_media(uuid) from public;
-- solo uso interno vía security definer

-- Borra preguntas creadas en un mes (Europe/Madrid). No toca ranking.
create or replace function public.quiz_delete_questions_for_month(p_year_month text)
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_id uuid;
  v_deleted int := 0;
  v_skipped_live int := 0;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo admin';
  end if;

  if p_year_month is null or p_year_month !~ '^[0-9]{4}-[0-9]{2}$' then
    raise exception 'Mes inválido (YYYY-MM)';
  end if;

  for v_id in
    select q.id
    from public.quiz_questions q
    where to_char(timezone('Europe/Madrid', q.created_at), 'YYYY-MM') = p_year_month
  loop
    if exists (
      select 1 from public.quiz_rounds r
      where r.question_id = v_id and r.status = 'live'
    ) then
      v_skipped_live := v_skipped_live + 1;
      continue;
    end if;

    delete from public.quiz_rounds where question_id = v_id;
    perform public.quiz_delete_question_media(v_id);
    delete from public.quiz_questions where id = v_id;
    v_deleted := v_deleted + 1;
  end loop;

  return jsonb_build_object(
    'deleted', v_deleted,
    'skippedLive', v_skipped_live,
    'yearMonth', p_year_month
  );
end;
$$;

revoke all on function public.quiz_delete_questions_for_month(text) from public;
grant execute on function public.quiz_delete_questions_for_month(text) to authenticated;


-- ###########################################################################
-- FILE: staff_notifications_overview.sql
-- ###########################################################################

-- Cofradeo · visión global de notificaciones / push (solo admin)
-- Ejecutar en Supabase SQL Editor.

-- ---------------------------------------------------------------------------
-- KPIs + volumen por tipo (últimos N días)
-- ---------------------------------------------------------------------------
create or replace function public.get_notifications_admin_overview(
  p_days int default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_days int := greatest(1, least(coalesce(p_days, 30), 90));
  v_since timestamptz := now() - make_interval(days => v_days);
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  select jsonb_build_object(
    'days', v_days,
    'since', v_since,
    'totalUsers', (
      select count(*)::int from public.profiles
    ),
    'pushEnabledUsers', (
      select count(*)::int
      from public.notification_preferences
      where push_enabled = true
    ),
    'pushDisabledUsers', (
      select count(*)::int
      from public.profiles p
      left join public.notification_preferences np on np.user_id = p.id
      where coalesce(np.push_enabled, false) = false
    ),
    'pushOnWithDevice', (
      select count(*)::int
      from public.notification_preferences np
      where np.push_enabled = true
        and exists (
          select 1 from public.device_tokens dt where dt.user_id = np.user_id
        )
    ),
    'pushOnNoDevice', (
      select count(*)::int
      from public.notification_preferences np
      where np.push_enabled = true
        and not exists (
          select 1 from public.device_tokens dt where dt.user_id = np.user_id
        )
    ),
    'usersWithToken', (
      select count(distinct user_id)::int
      from public.device_tokens
    ),
    'tokenCount', (
      select count(*)::int
      from public.device_tokens
    ),
    'tokensByPlatform', coalesce((
      select jsonb_object_agg(platform, cnt)
      from (
        select coalesce(nullif(trim(platform), ''), 'unknown') as platform,
               count(*)::int as cnt
        from public.device_tokens
        group by 1
      ) t
    ), '{}'::jsonb),
    'notificationsTotal', (
      select count(*)::int
      from public.notifications
      where created_at >= v_since
    ),
    'byType', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'type', type,
          'count', cnt
        )
        order by cnt desc
      )
      from (
        select type, count(*)::int as cnt
        from public.notifications
        where created_at >= v_since
        group by type
      ) s
    ), '[]'::jsonb),
    'byDay', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'day', day,
          'count', cnt
        )
        order by day desc
      )
      from (
        select (created_at::date) as day,
               count(*)::int as cnt
        from public.notifications
        where created_at >= v_since
        group by 1
      ) d
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.get_notifications_admin_overview(int) to authenticated;

-- ---------------------------------------------------------------------------
-- Diagnóstico por usuario (prefs + tokens, sin FCM completo)
-- ---------------------------------------------------------------------------
create or replace function public.get_notifications_user_diag(
  p_handle text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_handle text := lower(trim(both from coalesce(p_handle, '')));
  v_profile record;
  v_prefs jsonb;
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  if v_handle = '' then
    raise exception 'Indica un handle';
  end if;

  if left(v_handle, 1) = '@' then
    v_handle := substr(v_handle, 2);
  end if;

  select id, handle, display_name, role
  into v_profile
  from public.profiles
  where lower(handle) = v_handle
  limit 1;

  if not found then
    return jsonb_build_object('found', false, 'handle', v_handle);
  end if;

  select to_jsonb(np) - 'user_id' - 'updated_at'
  into v_prefs
  from public.notification_preferences np
  where np.user_id = v_profile.id;

  select jsonb_build_object(
    'found', true,
    'userId', v_profile.id,
    'handle', v_profile.handle,
    'displayName', v_profile.display_name,
    'role', v_profile.role,
    'pushEnabled', coalesce((v_prefs ->> 'push_enabled')::boolean, false),
    'prefs', v_prefs,
    'tokens', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'platform', coalesce(nullif(trim(dt.platform), ''), 'unknown'),
          'tokenPreview', left(dt.fcm_token, 12) || '…',
          'updatedAt', dt.updated_at
        )
        order by dt.updated_at desc nulls last
      )
      from public.device_tokens dt
      where dt.user_id = v_profile.id
    ), '[]'::jsonb),
    'tokenCount', (
      select count(*)::int
      from public.device_tokens
      where user_id = v_profile.id
    ),
    'recentNotifications', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', n.id,
          'type', n.type,
          'title', n.title,
          'createdAt', n.created_at,
          'read', n.read_at is not null
        )
        order by n.created_at desc
      )
      from (
        select *
        from public.notifications
        where user_id = v_profile.id
        order by created_at desc
        limit 20
      ) n
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.get_notifications_user_diag(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Listado de usuarios por estado de push
-- p_filter: 'all' | 'on' | 'off' | 'on_no_token' | 'off_with_token'
-- ---------------------------------------------------------------------------
create or replace function public.list_push_users(
  p_filter text default 'all',
  p_search text default null,
  p_limit int default 100,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_filter text := lower(trim(coalesce(p_filter, 'all')));
  v_search text := lower(trim(both from coalesce(p_search, '')));
  v_limit int := greatest(1, least(coalesce(p_limit, 100), 300));
  v_offset int := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_admin_user(auth.uid()) then
    raise exception 'Solo administradores';
  end if;

  if left(v_search, 1) = '@' then
    v_search := substr(v_search, 2);
  end if;

  with base as (
    select
      p.id,
      p.handle,
      p.display_name,
      p.role,
      coalesce(np.push_enabled, false) as push_enabled,
      coalesce(tok.token_count, 0)::int as token_count,
      tok.platforms,
      case
        when np.user_id is null then null
        else to_jsonb(np) - 'user_id' - 'updated_at' - 'push_enabled'
      end as prefs
    from public.profiles p
    left join public.notification_preferences np on np.user_id = p.id
    left join lateral (
      select
        count(*)::int as token_count,
        string_agg(distinct coalesce(nullif(trim(dt.platform), ''), 'unknown'), ', ' order by coalesce(nullif(trim(dt.platform), ''), 'unknown')) as platforms
      from public.device_tokens dt
      where dt.user_id = p.id
    ) tok on true
    where (
      v_search = ''
      or lower(p.handle) like '%' || v_search || '%'
      or lower(coalesce(p.display_name, '')) like '%' || v_search || '%'
    )
    and (
      v_filter = 'all'
      or (v_filter = 'on' and coalesce(np.push_enabled, false) = true)
      or (v_filter = 'off' and coalesce(np.push_enabled, false) = false)
      or (
        v_filter = 'on_no_token'
        and coalesce(np.push_enabled, false) = true
        and coalesce(tok.token_count, 0) = 0
      )
      or (
        v_filter = 'off_with_token'
        and coalesce(np.push_enabled, false) = false
        and coalesce(tok.token_count, 0) > 0
      )
    )
  ),
  counted as (
    select count(*)::int as total from base
  ),
  page as (
    select *
    from base
    order by
      push_enabled desc,
      token_count desc,
      handle asc
    limit v_limit
    offset v_offset
  )
  select jsonb_build_object(
    'total', (select total from counted),
    'limit', v_limit,
    'offset', v_offset,
    'filter', v_filter,
    'rows', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'userId', page.id,
          'handle', page.handle,
          'displayName', page.display_name,
          'role', page.role,
          'pushEnabled', page.push_enabled,
          'tokenCount', page.token_count,
          'platforms', coalesce(page.platforms, ''),
          'prefs', page.prefs
        )
      )
      from page
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.list_push_users(text, text, int, int) to authenticated;


-- ###########################################################################
-- FILE: notifications_realtime.sql
-- ###########################################################################

-- Círculo Cofrade · Realtime en la bandeja de notificaciones
-- Ejecutar una vez en SQL Editor para que la app reciba INSERT/UPDATE/DELETE al vuelo.

alter publication supabase_realtime add table public.notifications;


-- ###########################################################################
-- FILE: forum_topics_replies_realtime.sql
-- ###########################################################################

-- Cofradero · Realtime en temas y respuestas del foro
-- Ejecutar una vez en SQL Editor.
-- Permite que quien esté en un foro/hilo vea temas nuevos (publicados)
-- y comentarios nuevos sin tirar para refrescar.

-- Replica identity FULL: filtros por forum_id / topic_id también en DELETE/UPDATE.
alter table public.forum_topics replica identity full;
alter table public.forum_replies replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.forum_topics;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_replies;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- FILE: forum_pillars_realtime.sql
-- ###########################################################################

-- Cofradero · Realtime en pilares de foro y app_config (hero de FOROS)
-- Ejecutar una vez en SQL Editor para sincronizar portadas/iconos al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.forum_pillars;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.app_config;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- FILE: forum_moderators_realtime.sql
-- ###########################################################################

-- Cofradero · Realtime en asignaciones de moderadores
-- Ejecutar una vez en SQL Editor para que los permisos se actualicen al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.forum_moderators;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- FILE: calendar_events_realtime.sql
-- ###########################################################################

-- Cofradero · Realtime en eventos del calendario
-- Ejecutar una vez en SQL Editor para que el calendario se actualice al vuelo
-- (aprobaciones de la Junta, publicaciones, etc.).

do $$
begin
  alter publication supabase_realtime add table public.calendar_events;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- FILE: liturgical_countdown_realtime.sql
-- ###########################################################################

-- Cofradero · Realtime en configuración de cuenta atrás litúrgica
-- Ejecutar una vez en SQL Editor para sincronizar activar/ocultar al vuelo.

do $$
begin
  alter publication supabase_realtime add table public.liturgical_countdown_settings;
exception
  when duplicate_object then null;
end $$;


-- ###########################################################################
-- OPCIONAL (puede fallar sin pg_cron / webhook / Edge)
-- ###########################################################################

-- Los siguientes bloques están comentados a propósito.
-- Descomenta solo si ya tienes la extensión/config en pre.


-- ###########################################################################
-- OPTIONAL (comentado): calendar_event_reminders_cron.sql
-- ###########################################################################

-- -- Cofradero · programar recordatorios de calendario (pg_cron)
-- -- Ejecutar DESPUÉS de calendar_event_reminders.sql
-- --
-- -- 1. Supabase Dashboard → Database → Extensions → activar **pg_cron**
-- -- 2. Pega y ejecuta este script en SQL Editor
-- 
-- create extension if not exists pg_cron with schema extensions;
-- 
-- select cron.unschedule(jobid)
-- from cron.job
-- where jobname = 'dispatch-calendar-event-reminders';
-- 
-- select cron.schedule(
--   'dispatch-calendar-event-reminders',
--   '*/15 * * * *',
--   $$ select public.dispatch_calendar_event_reminders(); $$
-- );
-- 
-- -- Comprobar que el job quedó registrado:
-- -- select jobid, jobname, schedule, command from cron.job
-- -- where jobname = 'dispatch-calendar-event-reminders';
--


-- ###########################################################################
-- OPTIONAL (comentado): push_webhook_trigger.sql
-- ###########################################################################

-- -- Cofradero · disparar push al insertar en notifications (sin Dashboard Webhooks)
-- -- Usar si al crear el webhook sale: schema "supabase_functions" does not exist
-- -- Ejecutar en SQL Editor (una sola vez).
-- 
-- create extension if not exists pg_net with schema extensions;
-- 
-- create or replace function public.trigger_send_push_notification()
-- returns trigger
-- language plpgsql
-- security definer
-- set search_path = public
-- as $$
-- begin
--   perform net.http_post(
--     url := 'https://dcsxgppprfedrsrtbatx.supabase.co/functions/v1/send-push',
--     headers := jsonb_build_object('Content-Type', 'application/json'),
--     body := jsonb_build_object(
--       'type', 'INSERT',
--       'table', 'notifications',
--       'record', jsonb_build_object(
--         'user_id', new.user_id,
--         'type', new.type,
--         'title', new.title,
--         'subtitle', new.subtitle,
--         'payload', coalesce(new.payload, '{}'::jsonb)
--       )
--     )
--   );
--   return new;
-- end;
-- $$;
-- 
-- drop trigger if exists notifications_send_push on public.notifications;
-- create trigger notifications_send_push
--   after insert on public.notifications
--   for each row
--   execute function public.trigger_send_push_notification();
--
