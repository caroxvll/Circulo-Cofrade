-- La tarjeta de foro no debe mostrar hubs estacionales (Glorias, Cuaresma, SS)
-- como «última actividad». Solo temas de comunidad reales.
-- Ejecutar en SQL Editor y deja recalculados los pilares.

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
  v_last_topic_excerpt text;
  v_last_activity timestamptz;
begin
  select count(*)::int
  into v_topic_count
  from public.forum_topics
  where forum_id = p_forum_id
    and status = 'published'
    and coalesce(is_system, false) = false;

  select count(*)::int
  into v_reply_count
  from public.forum_replies r
  join public.forum_topics t on t.id = r.topic_id
  where t.forum_id = p_forum_id
    and t.status = 'published'
    and coalesce(t.is_system, false) = false;

  select ta.topic_id, ta.title, ta.excerpt, ta.activity_at
  into v_last_topic_id, v_last_topic_title, v_last_topic_excerpt, v_last_activity
  from (
    select
      t.id as topic_id,
      t.title,
      t.excerpt,
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
      and coalesce(t.is_system, false) = false
  ) ta
  order by ta.activity_at desc
  limit 1;

  update public.forum_pillars
  set
    topic_count = coalesce(v_topic_count, 0),
    message_count = coalesce(v_reply_count, 0),
    last_activity_at = v_last_activity,
    last_topic_id = v_last_topic_id,
    last_topic_title = v_last_topic_title,
    last_topic_excerpt = v_last_topic_excerpt
  where id = p_forum_id;
end;
$$;

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
