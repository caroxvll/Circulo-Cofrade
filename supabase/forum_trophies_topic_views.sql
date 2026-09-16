-- Cofradeo · trofeos al registrar visitas en temas
-- Ejecutar después de forum_trophies.sql y topic_views_dedup.sql

create or replace function public.increment_topic_view(
  p_topic_id text,
  p_viewer_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int;
  v_author_id uuid;
begin
  insert into public.topic_views (topic_id, viewer_id, viewed_on)
  values (p_topic_id, p_viewer_id, current_date)
  on conflict (topic_id, viewer_id, viewed_on) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.forum_topics
    set view_count = view_count + 1
    where id = p_topic_id
    returning author_id into v_author_id;

    perform public.sync_forum_trophies(v_author_id);
  end if;
end;
$$;

grant execute on function public.increment_topic_view(text, text) to anon, authenticated;
