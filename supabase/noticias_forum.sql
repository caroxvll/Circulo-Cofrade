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
