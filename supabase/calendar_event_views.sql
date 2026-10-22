-- Visitas por evento de calendario (1 por viewer y día).
-- Ejecutar en SQL Editor.

alter table public.calendar_events
  add column if not exists view_count integer not null default 0;

create table if not exists public.calendar_event_views (
  event_id uuid not null references public.calendar_events (id) on delete cascade,
  viewer_id text not null,
  viewed_on date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (event_id, viewer_id, viewed_on)
);

create index if not exists calendar_event_views_event_id_idx
  on public.calendar_event_views (event_id);

alter table public.calendar_event_views enable row level security;

drop policy if exists "Sin lectura directa de visitas evento" on public.calendar_event_views;
create policy "Sin lectura directa de visitas evento"
  on public.calendar_event_views for select using (false);

create or replace function public.increment_calendar_event_view(
  p_event_id uuid,
  p_viewer_id text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int;
  v_count int;
  v_viewer text := left(trim(coalesce(p_viewer_id, '')), 128);
begin
  if p_event_id is null or char_length(v_viewer) < 4 then
    return coalesce(
      (select view_count from public.calendar_events where id = p_event_id),
      0
    );
  end if;

  if not exists (
    select 1
    from public.calendar_events e
    where e.id = p_event_id
      and e.status = 'published'
  ) then
    return 0;
  end if;

  insert into public.calendar_event_views (event_id, viewer_id, viewed_on)
  values (p_event_id, v_viewer, current_date)
  on conflict (event_id, viewer_id, viewed_on) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.calendar_events
    set view_count = view_count + 1
    where id = p_event_id
    returning view_count into v_count;
  else
    select view_count into v_count
    from public.calendar_events
    where id = p_event_id;
  end if;

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.increment_calendar_event_view(uuid, text) from public;
grant execute on function public.increment_calendar_event_view(uuid, text)
  to anon, authenticated;

notify pgrst, 'reload schema';
