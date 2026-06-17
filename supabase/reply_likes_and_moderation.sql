-- Cofradero · likes en respuestas (Fase 8f)
-- Ejecutar en SQL Editor

create table if not exists public.forum_reply_likes (
  reply_id uuid not null references public.forum_replies (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reply_id, user_id)
);

alter table public.forum_reply_likes enable row level security;

create policy "Likes legibles por todos"
  on public.forum_reply_likes for select using (true);

create policy "Usuario da me gusta si no suspendido"
  on public.forum_reply_likes for insert
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

create policy "Usuario quita sus me gusta"
  on public.forum_reply_likes for delete
  using (auth.uid() = user_id);

create or replace function public.sync_reply_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.forum_replies
    set like_count = like_count + 1
    where id = new.reply_id;
  elsif tg_op = 'DELETE' then
    update public.forum_replies
    set like_count = greatest(like_count - 1, 0)
    where id = old.reply_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists on_reply_like_count on public.forum_reply_likes;
create trigger on_reply_like_count
  after insert or delete on public.forum_reply_likes
  for each row execute function public.sync_reply_like_count();
