-- Cofradero · REPARACIÓN si reply_reactions.sql falló con error 23514
-- (filas con emoji mezcladas con el constraint antiguo)
-- Ejecuta ESTE archivo entero en SQL Editor; es idempotente.

alter table public.forum_reply_likes
  add column if not exists reaction text not null default '❤️';

alter table public.forum_reply_likes
  drop constraint if exists forum_reply_likes_reaction_check;

update public.forum_reply_likes
set reaction = case reaction
  when 'heart' then '❤️'
  when 'pray' then '🙏'
  when 'candle' then '🕯️'
  when 'amen' then '✨'
  when 'clap' then '👏'
  when 'moved' then '😢'
  when 'dislike' then '👎'
  when 'thanks' then '🤗'
  when '🫶' then '🤗'
  else reaction
end;

alter table public.forum_reply_likes
  add constraint forum_reply_likes_reaction_check
  check (char_length(reaction) >= 1 and char_length(reaction) <= 16);

alter table public.forum_reply_likes
  alter column reaction set default '❤️';

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

do $$
begin
  alter publication supabase_realtime add table public.forum_reply_likes;
exception
  when duplicate_object then null;
end $$;

-- Obliga a PostgREST a ver la columna nueva (si no, la app sigue diciendo que falta).
notify pgrst, 'reload schema';
