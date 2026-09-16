-- Cofradero · reacciones en respuestas (extiende forum_reply_likes)
-- Ejecutar después de reply_likes_and_moderation.sql
-- Luego ejecuta reply_reactions_emoji.sql (emojis + Realtime).

alter table public.forum_reply_likes
  add column if not exists reaction text not null default 'heart';

-- Quita constraint antiguo si existe (p. ej. re-ejecución o datos mixtos).
alter table public.forum_reply_likes
  drop constraint if exists forum_reply_likes_reaction_check;

comment on column public.forum_reply_likes.reaction is
  'Reacción (emoji unicode tras reply_reactions_emoji.sql)';

drop policy if exists "Usuario cambia su reacción" on public.forum_reply_likes;
create policy "Usuario cambia su reacción"
  on public.forum_reply_likes for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

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

create or replace function public.reply_reaction_counts(p_reply_ids uuid[])
returns table (reply_id uuid, reaction text, reaction_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select l.reply_id, l.reaction, count(*)::bigint
  from public.forum_reply_likes l
  where l.reply_id = any (p_reply_ids)
  group by l.reply_id, l.reaction;
$$;

grant execute on function public.reply_reaction_counts(uuid[]) to authenticated, anon;
