-- Cofradero · Endurecimiento de escala (v1)
-- Ejecutar en SQL Editor. Idempotente.
--
-- Si un intento anterior falló a medias, esto limpia una columna topic_id uuid errónea:
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'forum_reply_likes'
      and column_name = 'topic_id'
      and data_type = 'uuid'
  ) then
    alter table public.forum_reply_likes drop column topic_id;
  end if;
end $$;

-- Si notification_dispatch_jobs se creó con source_id uuid, recrear (solo si está vacía).
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'notification_dispatch_jobs'
      and column_name = 'source_id'
      and data_type = 'uuid'
  ) then
    if (select count(*) from public.notification_dispatch_jobs) = 0 then
      drop table public.notification_dispatch_jobs;
    end if;
  end if;
exception
  when undefined_table then null;
end $$;

-- Después de ejecutar:
--   notify pgrst, 'reload schema';
-- Cron (cada minuto) o a mano tras noticias grandes:
--   select public.process_notification_dispatch(500);
--
-- =============================================================================
-- 1) Reacciones de comentarios: topic_id para filtrar Realtime por hilo
-- =============================================================================
alter table public.forum_reply_likes
  add column if not exists topic_id text references public.forum_topics (id) on delete cascade;

update public.forum_reply_likes l
set topic_id = r.topic_id
from public.forum_replies r
where l.reply_id = r.id
  and l.topic_id is null;

create index if not exists forum_reply_likes_topic_id_idx
  on public.forum_reply_likes (topic_id);

create or replace function public.set_reply_like_topic_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.topic_id is null then
    select r.topic_id into new.topic_id
    from public.forum_replies r
    where r.id = new.reply_id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_reply_like_set_topic on public.forum_reply_likes;
create trigger on_reply_like_set_topic
  before insert or update of reply_id on public.forum_reply_likes
  for each row execute function public.set_reply_like_topic_id();

-- Listado de quién reaccionó: tope para hilos virales
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
  order by l.created_at desc
  limit 100;
$$;

grant execute on function public.reply_reaction_users(uuid) to authenticated, anon;

-- =============================================================================
-- 2) Índices de follows / notifications (fan-out y bandeja)
-- =============================================================================
create index if not exists follows_target_lookup_idx
  on public.follows (target_type, target_id);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_created_idx
  on public.notifications (created_at);

-- Limpieza opcional: borra notificaciones leídas de más de 90 días.
-- Llamar a mano o con cron: select public.purge_old_notifications(90);
create or replace function public.purge_old_notifications(p_days int default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted int;
begin
  delete from public.notifications
  where read_at is not null
    and created_at < now() - make_interval(days => greatest(p_days, 7));
  get diagnostics deleted = row_count;
  return deleted;
end;
$$;

revoke all on function public.purge_old_notifications(int) from public;
grant execute on function public.purge_old_notifications(int) to service_role;

-- =============================================================================
-- 3) Cola de fan-out para Noticias (publicar ya no inserta 10k filas de golpe)
-- =============================================================================
create table if not exists public.notification_dispatch_jobs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('news_published')),
  source_id text not null,
  title text not null,
  subtitle text,
  payload jsonb not null default '{}'::jsonb,
  author_id uuid,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'done', 'failed')),
  cursor_created_at timestamptz,
  cursor_follower_id uuid,
  processed_count int not null default 0,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists notification_dispatch_jobs_status_idx
  on public.notification_dispatch_jobs (status, created_at);

alter table public.notification_dispatch_jobs enable row level security;

-- Solo service_role / security definer; sin policies públicas de escritura.

create or replace function public.enqueue_noticias_notify()
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

  insert into public.notification_dispatch_jobs (
    kind, source_id, title, subtitle, payload, author_id
  ) values (
    'news_published',
    new.id,
    'Nueva noticia',
    left(new.title, 80),
    jsonb_build_object(
      'forumId', new.forum_id,
      'topicId', new.id
    ),
    new.author_id
  );

  return new;
end;
$$;

-- Sustituye el fan-out síncrono por la cola.
drop trigger if exists on_noticias_published_notify on public.forum_topics;
create trigger on_noticias_published_notify
  after insert or update of status on public.forum_topics
  for each row execute function public.enqueue_noticias_notify();

-- Procesa hasta p_limit seguidores por llamada (push sigue yendo por webhook/trigger
-- al insertar cada notification, pero repartido en el tiempo).
create or replace function public.process_notification_dispatch(p_limit int default 500)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.notification_dispatch_jobs%rowtype;
  batch_limit int := least(greatest(coalesce(p_limit, 500), 50), 2000);
  inserted int := 0;
  last_created timestamptz;
  last_follower uuid;
begin
  perform set_config('row_security', 'off', true);

  select * into job
  from public.notification_dispatch_jobs
  where status in ('pending', 'processing')
  order by created_at
  for update skip locked
  limit 1;

  if not found then
    return jsonb_build_object('ok', true, 'processed', 0, 'reason', 'idle');
  end if;

  update public.notification_dispatch_jobs
  set status = 'processing', updated_at = now()
  where id = job.id;

  with candidates as (
    select
      f.follower_id,
      f.created_at as follow_created_at
    from public.follows f
    join public.profiles p on p.id = f.follower_id
    where f.target_type = 'forum'
      and f.target_id = 'noticias'
      and p.suspended_at is null
      and f.follower_id is distinct from job.author_id
      and public.notify_pref_enabled(f.follower_id, 'news')
      and (
        job.cursor_created_at is null
        or (f.created_at, f.follower_id)
             > (job.cursor_created_at, job.cursor_follower_id)
      )
      and not exists (
        select 1
        from public.notifications n
        where n.user_id = f.follower_id
          and n.type = 'news_published'
          and n.payload->>'topicId' = job.source_id
      )
    order by f.created_at, f.follower_id
    limit batch_limit
  ),
  inserted_rows as (
    insert into public.notifications (user_id, type, title, subtitle, payload)
    select
      c.follower_id,
      'news_published',
      job.title,
      job.subtitle,
      job.payload
    from candidates c
    returning 1
  )
  select
    (select count(*)::int from inserted_rows),
    (select c.follow_created_at
       from candidates c
       order by c.follow_created_at desc, c.follower_id desc
       limit 1),
    (select c.follower_id
       from candidates c
       order by c.follow_created_at desc, c.follower_id desc
       limit 1)
  into inserted, last_created, last_follower;

  if coalesce(inserted, 0) = 0 then
    update public.notification_dispatch_jobs
    set
      status = 'done',
      updated_at = now(),
      error_message = null
    where id = job.id;
    return jsonb_build_object(
      'ok', true,
      'jobId', job.id,
      'processed', 0,
      'status', 'done'
    );
  end if;

  update public.notification_dispatch_jobs
  set
    cursor_created_at = last_created,
    cursor_follower_id = last_follower,
    processed_count = processed_count + inserted,
    updated_at = now(),
    status = case when inserted < batch_limit then 'done' else 'processing' end,
    error_message = null
  where id = job.id;

  return jsonb_build_object(
    'ok', true,
    'jobId', job.id,
    'processed', inserted,
    'status', case when inserted < batch_limit then 'done' else 'processing' end
  );
exception
  when others then
    update public.notification_dispatch_jobs
    set
      status = 'failed',
      error_message = left(sqlerrm, 400),
      updated_at = now()
    where id = job.id;
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

revoke all on function public.process_notification_dispatch(int) from public;
grant execute on function public.process_notification_dispatch(int) to service_role;

comment on table public.notification_dispatch_jobs is
  'Cola de fan-out (Noticias). Publicar encola; process_notification_dispatch inserta por lotes.';

comment on function public.process_notification_dispatch(int) is
  'Procesa un job pendiente (hasta p_limit notificaciones). Programar cada 1 min.';

-- Recarga la API de Supabase (PostgREST) para ver columnas/RPCs nuevas al momento.
notify pgrst, 'reload schema';
