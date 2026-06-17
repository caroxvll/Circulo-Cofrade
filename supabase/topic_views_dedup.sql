-- Cofradero · visitas deduplicadas (1 por viewer y día)
-- Ejecutar en SQL Editor (sustituye la función anterior de topic_view_counter.sql)

create table if not exists public.topic_views (
  topic_id text not null references public.forum_topics (id) on delete cascade,
  viewer_id text not null,
  viewed_on date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (topic_id, viewer_id, viewed_on)
);

create index if not exists topic_views_topic_id_idx
  on public.topic_views (topic_id);

alter table public.topic_views enable row level security;

-- Solo la función RPC escribe; los clientes no leen esta tabla directamente.
create policy "Sin lectura directa de visitas"
  on public.topic_views for select using (false);

drop function if exists public.increment_topic_view(text);

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
begin
  insert into public.topic_views (topic_id, viewer_id, viewed_on)
  values (p_topic_id, p_viewer_id, current_date)
  on conflict (topic_id, viewer_id, viewed_on) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.forum_topics
    set view_count = view_count + 1
    where id = p_topic_id;
  end if;
end;
$$;

grant execute on function public.increment_topic_view(text, text) to anon, authenticated;
