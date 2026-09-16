-- Cofradeo · reacciones y respuestas a avisos SS
-- Ejecutar en SQL Editor DESPUÉS de ss_live_updates.sql
-- Idempotente.

-- ─── Reacciones (1 por usuario / aviso) ─────────────────────────────────────

create table if not exists public.ss_live_update_likes (
  update_id uuid not null references public.ss_live_updates (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  reaction text not null default '❤️'
    check (char_length(reaction) >= 1 and char_length(reaction) <= 16),
  created_at timestamptz not null default now(),
  primary key (update_id, user_id)
);

create index if not exists ss_live_update_likes_update_id_idx
  on public.ss_live_update_likes (update_id);

alter table public.ss_live_update_likes enable row level security;

drop policy if exists "Reacciones aviso SS legibles" on public.ss_live_update_likes;
create policy "Reacciones aviso SS legibles"
  on public.ss_live_update_likes for select
  to authenticated
  using (true);

drop policy if exists "Usuario reacciona a aviso SS" on public.ss_live_update_likes;
create policy "Usuario reacciona a aviso SS"
  on public.ss_live_update_likes for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario cambia reacción aviso SS" on public.ss_live_update_likes;
create policy "Usuario cambia reacción aviso SS"
  on public.ss_live_update_likes for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario quita reacción aviso SS" on public.ss_live_update_likes;
create policy "Usuario quita reacción aviso SS"
  on public.ss_live_update_likes for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.ss_live_reaction_counts(p_update_ids uuid[])
returns table (update_id uuid, reaction text, reaction_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select l.update_id, l.reaction, count(*)::bigint
  from public.ss_live_update_likes l
  where l.update_id = any (p_update_ids)
  group by l.update_id, l.reaction;
$$;

grant execute on function public.ss_live_reaction_counts(uuid[]) to authenticated, anon;

-- ─── Respuestas planas ──────────────────────────────────────────────────────

create table if not exists public.ss_live_update_replies (
  id uuid primary key default gen_random_uuid(),
  update_id uuid not null references public.ss_live_updates (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  message text not null
    check (char_length(trim(message)) between 1 and 280),
  created_at timestamptz not null default now()
);

create index if not exists ss_live_update_replies_update_created_idx
  on public.ss_live_update_replies (update_id, created_at asc);

alter table public.ss_live_update_replies enable row level security;

drop policy if exists "Respuestas aviso SS legibles" on public.ss_live_update_replies;
create policy "Respuestas aviso SS legibles"
  on public.ss_live_update_replies for select
  to authenticated
  using (true);

drop policy if exists "Cofrade responde aviso SS" on public.ss_live_update_replies;
create policy "Cofrade responde aviso SS"
  on public.ss_live_update_replies for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.suspended_at is not null
    )
  );

drop policy if exists "Usuario borra su respuesta SS" on public.ss_live_update_replies;
create policy "Usuario borra su respuesta SS"
  on public.ss_live_update_replies for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.ss_live_reply_counts(p_update_ids uuid[])
returns table (update_id uuid, reply_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select r.update_id, count(*)::bigint
  from public.ss_live_update_replies r
  where r.update_id = any (p_update_ids)
  group by r.update_id;
$$;

grant execute on function public.ss_live_reply_counts(uuid[]) to authenticated, anon;

alter table public.ss_live_update_likes replica identity full;
alter table public.ss_live_update_replies replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.ss_live_update_likes;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.ss_live_update_replies;
exception
  when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
