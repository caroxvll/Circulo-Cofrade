-- Visitas por comunicado oficial (1 por viewer y día), espejo de topic_views.
-- Ejecutar en SQL Editor.

alter table public.forum_replies
  add column if not exists view_count integer not null default 0;

create table if not exists public.reply_views (
  reply_id uuid not null references public.forum_replies (id) on delete cascade,
  viewer_id text not null,
  viewed_on date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (reply_id, viewer_id, viewed_on)
);

create index if not exists reply_views_reply_id_idx
  on public.reply_views (reply_id);

alter table public.reply_views enable row level security;

drop policy if exists "Sin lectura directa de visitas reply" on public.reply_views;
create policy "Sin lectura directa de visitas reply"
  on public.reply_views for select using (false);

create or replace function public.increment_official_reply_view(
  p_reply_id uuid,
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
  if p_reply_id is null or char_length(v_viewer) < 4 then
    return coalesce(
      (select view_count from public.forum_replies where id = p_reply_id),
      0
    );
  end if;

  -- Solo comunicados oficiales publicados
  if not exists (
    select 1
    from public.forum_replies r
    where r.id = p_reply_id
      and r.is_official = true
      and r.deleted_at is null
  ) then
    return 0;
  end if;

  insert into public.reply_views (reply_id, viewer_id, viewed_on)
  values (p_reply_id, v_viewer, current_date)
  on conflict (reply_id, viewer_id, viewed_on) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.forum_replies
    set view_count = view_count + 1
    where id = p_reply_id
    returning view_count into v_count;
  else
    select view_count into v_count
    from public.forum_replies
    where id = p_reply_id;
  end if;

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.increment_official_reply_view(uuid, text) from public;
grant execute on function public.increment_official_reply_view(uuid, text)
  to anon, authenticated;

notify pgrst, 'reload schema';
