-- Cofradeo · Cuentas que pueden publicar noticias (solo eso)
-- y carrusel al unir la misma noticia de varias cuentas.
-- Ejecutar en el SQL Editor después de noticias_forum.sql.
-- Idempotente.

-- ---------------------------------------------------------------------------
-- 1) Lista manual. No es la verificación de hermandad.
-- ---------------------------------------------------------------------------
create table if not exists public.news_publishers (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null,
  assigned_at timestamptz not null default now(),
  note text not null default '' check (char_length(note) <= 200)
);

alter table public.news_publishers enable row level security;

drop policy if exists "Noticias: leer permiso propio o junta" on public.news_publishers;
create policy "Noticias: leer permiso propio o junta"
  on public.news_publishers for select
  to authenticated
  using (
    profile_id = auth.uid()
    or public.is_admin_user(auth.uid())
  );

drop policy if exists "Junta gestiona quien publica noticias" on public.news_publishers;
create policy "Junta gestiona quien publica noticias"
  on public.news_publishers for all
  to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

create or replace function public.is_news_publisher(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.news_publishers n
    join public.profiles p on p.id = n.profile_id
    where n.profile_id = p_user_id
      and p.suspended_at is null
  );
$$;

grant execute on function public.is_news_publisher(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 2) Esas cuentas publican al momento. No moderan ni tocan el calendario.
-- ---------------------------------------------------------------------------
create or replace function public.set_noticias_topic_status_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id is distinct from 'noticias' then
    return new;
  end if;

  if public.is_admin_user(new.author_id)
     or public.is_news_publisher(new.author_id) then
    new.status := 'published';
  elsif exists (
    select 1
    from public.forum_moderators fm
    where fm.profile_id = new.author_id
      and fm.forum_id = 'noticias'
  ) then
    new.status := 'pending';
  else
    raise exception 'Solo la Junta puede publicar noticias';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3) Agrupación manual. El orden del carrusel es el de publicación.
-- ---------------------------------------------------------------------------
alter table public.forum_topics
  add column if not exists news_group_id text;

create index if not exists forum_topics_news_group_id_idx
  on public.forum_topics (news_group_id)
  where news_group_id is not null;

create or replace function public.protect_news_group_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.news_group_id is distinct from old.news_group_id
     and not public.is_admin_user(auth.uid()) then
    new.news_group_id := old.news_group_id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_forum_topic_protect_news_group on public.forum_topics;
create trigger on_forum_topic_protect_news_group
  before update of news_group_id on public.forum_topics
  for each row execute function public.protect_news_group_id();

create or replace function public.unify_noticias(p_topic_ids text[])
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group text;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo la Junta puede unir noticias';
  end if;

  if coalesce(array_length(p_topic_ids, 1), 0) < 2 then
    raise exception 'Elige al menos dos noticias';
  end if;

  if exists (
    select 1
    from unnest(p_topic_ids) as tid
    where not exists (
      select 1
      from public.forum_topics t
      where t.id = tid
        and t.forum_id = 'noticias'
        and t.status = 'published'
    )
  ) then
    raise exception 'Solo se pueden unir noticias publicadas';
  end if;

  select t.news_group_id
    into v_group
  from public.forum_topics t
  where t.id = p_topic_ids[1]
    and t.news_group_id is not null;

  if v_group is null then
    select t.news_group_id
      into v_group
    from public.forum_topics t
    where t.id = any (p_topic_ids)
      and t.news_group_id is not null
    limit 1;
  end if;

  if v_group is null then
    v_group := gen_random_uuid()::text;
  end if;

  update public.forum_topics
  set news_group_id = v_group
  where id = any (p_topic_ids);

  return v_group;
end;
$$;

grant execute on function public.unify_noticias(text[]) to authenticated;

create or replace function public.split_noticia(p_topic_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group text;
  v_left int;
begin
  if not public.is_admin_user(auth.uid()) then
    raise exception 'Solo la Junta puede separar noticias';
  end if;

  select news_group_id
    into v_group
  from public.forum_topics
  where id = p_topic_id
    and forum_id = 'noticias';

  if v_group is null then
    return;
  end if;

  update public.forum_topics
  set news_group_id = null
  where id = p_topic_id;

  select count(*)
    into v_left
  from public.forum_topics
  where news_group_id = v_group;

  if v_left < 2 then
    update public.forum_topics
    set news_group_id = null
    where news_group_id = v_group;
  end if;
end;
$$;

grant execute on function public.split_noticia(text) to authenticated;

notify pgrst, 'reload schema';
