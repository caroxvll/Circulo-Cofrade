-- Cofradeo · cierre de huérfanos post/calendario/notificaciones
-- Ejecutar una vez (idempotente).

-- ─── 1) Enlace post → evento (si aún no está) ────────────────────────────────
alter table public.calendar_events
  add column if not exists source_reply_id uuid
    references public.forum_replies (id) on delete set null;

create index if not exists calendar_events_source_reply_id_idx
  on public.calendar_events (source_reply_id)
  where source_reply_id is not null;

-- ─── 2) Campos de calendario en posts programados ───────────────────────────
alter table public.hermandad_scheduled_posts
  add column if not exists image_url text;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_event_type text;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_starts_at timestamptz;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_location text;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_title text;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_cover_image_url text;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_custom_icon_url text;

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_organizer_label text;

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_calendar_type_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_calendar_type_check
  check (
    calendar_event_type is null
    or calendar_event_type in (
      'procesion', 'gloria', 'ensayo', 'iguala', 'concierto', 'evento'
    )
  );

-- ─── 3) Soft-delete reply: limpia eventos ligados + notificaciones ──────────
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

  -- Eventos de calendario nacidos de este comunicado
  delete from public.calendar_events
  where source_reply_id = p_reply_id;

  -- Notificaciones que apuntan a esta respuesta
  delete from public.notifications
  where payload->>'replyId' = p_reply_id::text;
end;
$$;

grant execute on function public.soft_delete_forum_reply(uuid) to authenticated;

-- ─── 4) Limpiar notificaciones al borrar evento / aviso SS / reply hard ─────
create or replace function public.cleanup_notifications_on_calendar_event_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.notifications
  where payload->>'eventId' = old.id::text;
  return old;
end;
$$;

drop trigger if exists trg_cleanup_notifications_calendar_event
  on public.calendar_events;
create trigger trg_cleanup_notifications_calendar_event
  after delete on public.calendar_events
  for each row
  execute function public.cleanup_notifications_on_calendar_event_delete();

create or replace function public.cleanup_notifications_on_ss_live_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.notifications
  where payload->>'updateId' = old.id::text;
  return old;
end;
$$;

drop trigger if exists trg_cleanup_notifications_ss_live
  on public.ss_live_updates;
create trigger trg_cleanup_notifications_ss_live
  after delete on public.ss_live_updates
  for each row
  execute function public.cleanup_notifications_on_ss_live_delete();

create or replace function public.cleanup_notifications_on_forum_reply_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.notifications
  where payload->>'replyId' = old.id::text;

  delete from public.calendar_events
  where source_reply_id = old.id;

  return old;
end;
$$;

drop trigger if exists trg_cleanup_notifications_forum_reply
  on public.forum_replies;
create trigger trg_cleanup_notifications_forum_reply
  after delete on public.forum_replies
  for each row
  execute function public.cleanup_notifications_on_forum_reply_delete();

-- ─── 5) Cron: publica reply (+ imagen) y evento de calendario si se pidió ───
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
  v_title text;
  v_organizer text;
  v_icon text;
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

    -- Calendario diferido (si se marcó al programar)
    if v_row.calendar_event_type is not null
       and v_row.calendar_starts_at is not null then
      v_title := nullif(trim(coalesce(v_row.calendar_title, '')), '');
      if v_title is null then
        v_title := nullif(
          trim(substring(v_row.content from '^\*\*(.+?)\*\*')),
          ''
        );
      end if;
      if v_title is null then
        v_title := left(regexp_replace(v_row.content, '\s+', ' ', 'g'), 80);
      end if;

      v_organizer := nullif(trim(coalesce(v_row.calendar_organizer_label, '')), '');
      if v_organizer is null then
        select coalesce(nullif(trim(p.display_name), ''), 'Hermandad')
        into v_organizer
        from public.profiles p
        where p.id = v_row.author_id;
      end if;

      v_icon := nullif(trim(coalesce(v_row.calendar_custom_icon_url, '')), '');
      if v_icon is null then
        select nullif(trim(t.icon_image_url), '')
        into v_icon
        from public.forum_topics t
        where t.id = v_row.topic_id;
      end if;

      insert into public.calendar_events (
        title,
        subtitle,
        event_type,
        starts_at,
        location,
        organizer_label,
        cover_image_url,
        custom_icon_url,
        created_by,
        status,
        source_reply_id
      ) values (
        left(v_title, 120),
        left(coalesce(v_organizer, 'Hermandad'), 240),
        v_row.calendar_event_type,
        v_row.calendar_starts_at,
        left(coalesce(v_row.calendar_location, ''), 160),
        left(coalesce(v_organizer, 'Hermandad'), 120),
        left(coalesce(v_row.calendar_cover_image_url, v_row.image_url, ''), 700),
        left(coalesce(v_icon, ''), 700),
        v_row.author_id,
        'published',
        v_reply_id
      );
    end if;

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

notify pgrst, 'reload schema';
