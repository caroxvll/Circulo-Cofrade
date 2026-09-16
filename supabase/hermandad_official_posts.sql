-- Cofradero · publicaciones oficiales en tablones de hermandades
-- Ejecutar después de schema.sql, admin_roles.sql y profile_verification.sql.

alter table public.forum_replies
  add column if not exists is_official boolean not null default false;

alter table public.forum_replies
  add column if not exists official_category text;

alter table public.forum_replies
  drop constraint if exists forum_replies_official_category_check;

alter table public.forum_replies
  add constraint forum_replies_official_category_check
  check (
    official_category is null
    or official_category in (
      'noticia', 'culto', 'acto', 'patrimonio'
    )
  );

create or replace function public.prevent_manual_hermandad_topics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.forum_id = 'hermandades'
     and auth.uid() is not null then
    raise exception 'Hermandades es un directorio informativo: no admite temas nuevos desde la app';
  end if;
  return new;
end;
$$;

drop trigger if exists on_hermandad_topics_guard on public.forum_topics;
create trigger on_hermandad_topics_guard
  before insert on public.forum_topics
  for each row execute function public.prevent_manual_hermandad_topics();

create table if not exists public.hermandad_topic_accounts (
  topic_id text not null references public.forum_topics (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (topic_id, profile_id)
);

alter table public.hermandad_topic_accounts enable row level security;

drop policy if exists "Asignaciones hermandad legibles por staff" on public.hermandad_topic_accounts;
create policy "Asignaciones hermandad legibles por staff"
  on public.hermandad_topic_accounts for select
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'moderator')
        and p.suspended_at is null
    )
  );

drop policy if exists "Admin gestiona asignaciones hermandad" on public.hermandad_topic_accounts;
create policy "Admin gestiona asignaciones hermandad"
  on public.hermandad_topic_accounts for all
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
        and p.suspended_at is null
    )
  )
  with check (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'admin'
        and p.suspended_at is null
    )
  );

create or replace function public.can_create_official_hermandad_post(
  p_user_id uuid,
  p_topic_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = p_user_id
      and suspended_at is null
      and role in ('admin', 'moderator')
  )
  or exists (
    select 1
    from public.profiles p
    join public.hermandad_topic_accounts a on a.profile_id = p.id
    where p.id = p_user_id
      and a.topic_id = p_topic_id
      and p.verified = true
      and p.suspended_at is null
  );
$$;

create or replace function public.prevent_invalid_official_hermandad_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_forum_id text;
begin
  select forum_id
  into v_forum_id
  from public.forum_topics
  where id = new.topic_id;

  if v_forum_id = 'hermandades' and coalesce(new.is_official, false) = false then
    raise exception 'Hermandades es un espacio informativo: solo admite publicaciones oficiales';
  end if;

  if coalesce(new.is_official, false) = false then
    new.official_category := null;
    return new;
  end if;

  if v_forum_id is distinct from 'hermandades' then
    raise exception 'Las publicaciones oficiales solo están disponibles en Hermandades';
  end if;

  if new.official_category is null then
    new.official_category := 'noticia';
  end if;

  if not public.can_create_official_hermandad_post(new.author_id, new.topic_id) then
    raise exception 'Solo la cuenta verificada asignada a esta hermandad o staff puede publicar información oficial';
  end if;

  return new;
end;
$$;

drop trigger if exists on_official_hermandad_post_guard on public.forum_replies;
create trigger on_official_hermandad_post_guard
  before insert or update of is_official, official_category, topic_id, author_id
  on public.forum_replies
  for each row execute function public.prevent_invalid_official_hermandad_post();

-- Ejemplo de asociación cuenta oficial -> tablón de hermandad:
-- insert into public.hermandad_topic_accounts (topic_id, profile_id)
-- select 'lunes-santo-san-pablo', id
-- from public.profiles
-- where handle = 'hdad_sanpablo';
