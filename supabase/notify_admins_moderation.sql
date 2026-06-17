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
