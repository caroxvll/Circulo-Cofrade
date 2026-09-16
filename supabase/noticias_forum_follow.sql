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
