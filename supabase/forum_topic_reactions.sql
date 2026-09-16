-- Cofradero · reacciones en temas (mismo catálogo emoji que respuestas)
-- Ejecutar tras reply_reactions_emoji.sql.
-- Idempotente.

create table if not exists public.forum_topic_likes (
  topic_id text not null references public.forum_topics (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  reaction text not null default '❤️'
    check (char_length(reaction) >= 1 and char_length(reaction) <= 16),
  created_at timestamptz not null default now(),
  primary key (topic_id, user_id)
);

create index if not exists forum_topic_likes_topic_id_idx
  on public.forum_topic_likes (topic_id);

alter table public.forum_topic_likes enable row level security;

drop policy if exists "Reacciones tema legibles" on public.forum_topic_likes;
create policy "Reacciones tema legibles"
  on public.forum_topic_likes for select using (true);

drop policy if exists "Usuario reacciona a tema" on public.forum_topic_likes;
create policy "Usuario reacciona a tema"
  on public.forum_topic_likes for insert
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario cambia reacción tema" on public.forum_topic_likes;
create policy "Usuario cambia reacción tema"
  on public.forum_topic_likes for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario quita reacción tema" on public.forum_topic_likes;
create policy "Usuario quita reacción tema"
  on public.forum_topic_likes for delete
  using (auth.uid() = user_id);

create or replace function public.topic_reaction_counts(p_topic_id text)
returns table (reaction text, reaction_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select l.reaction, count(*)::bigint
  from public.forum_topic_likes l
  where l.topic_id = p_topic_id
  group by l.reaction;
$$;

grant execute on function public.topic_reaction_counts(text) to authenticated, anon;

create or replace function public.topic_reaction_users(p_topic_id text)
returns table (
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text,
  reaction text,
  reacted_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    l.user_id,
    coalesce(p.handle, 'cofrade') as handle,
    coalesce(p.display_name, 'Cofrade') as display_name,
    p.avatar_url,
    l.reaction,
    l.created_at as reacted_at
  from public.forum_topic_likes l
  left join public.profiles p on p.id = l.user_id
  where l.topic_id = p_topic_id
  order by l.created_at desc;
$$;

grant execute on function public.topic_reaction_users(text) to authenticated, anon;

alter table public.forum_topic_likes replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.forum_topic_likes;
exception
  when duplicate_object then null;
end $$;
