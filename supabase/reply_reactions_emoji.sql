-- Cofradero · reacciones como emoji (ejecutar tras reply_reactions.sql)
-- Sin este script la app no puede guardar ❤️, 👏, 🤗, etc.

alter table public.forum_reply_likes
  drop constraint if exists forum_reply_likes_reaction_check;

-- Migrar ids legacy ANTES de crear el nuevo check.
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

comment on column public.forum_reply_likes.reaction is
  'Emoji unicode de la reacción';

alter table public.forum_reply_likes
  alter column reaction set default '❤️';

-- Realtime: otras pantallas ven reacciones al instante.
do $$
begin
  alter publication supabase_realtime add table public.forum_reply_likes;
exception
  when duplicate_object then null;
end $$;
