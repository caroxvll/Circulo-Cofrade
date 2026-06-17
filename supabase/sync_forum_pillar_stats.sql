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
