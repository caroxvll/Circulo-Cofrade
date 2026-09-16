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

create policy "Trofeos legibles por todos"
  on public.profile_trophies for select using (true);

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
