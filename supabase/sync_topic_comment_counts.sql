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
