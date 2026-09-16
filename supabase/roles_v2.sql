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
