-- Cofradeo · Quién puede proponer eventos al calendario.
-- Un moderador de foro ya puede. Esta lista es para quien no lo es.
-- Al dar este acceso también puede publicar noticias (ver la app).
-- Ejecutar en el SQL Editor después de news_publishers.sql y roles_v2.sql.
-- Idempotente.

create table if not exists public.calendar_contributors (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null,
  assigned_at timestamptz not null default now(),
  note text not null default '' check (char_length(note) <= 200)
);

alter table public.calendar_contributors enable row level security;

drop policy if exists "Calendario: leer permiso propio o junta" on public.calendar_contributors;
drop policy if exists "Calendario: el distintivo es público" on public.calendar_contributors;
create policy "Calendario: el distintivo es público"
  on public.calendar_contributors for select
  to authenticated, anon
  using (true);

-- El verificado dorado de noticias también tiene que verse en perfiles ajenos.
drop policy if exists "Noticias: leer permiso propio o junta" on public.news_publishers;
drop policy if exists "Noticias: el distintivo es público" on public.news_publishers;
create policy "Noticias: el distintivo es público"
  on public.news_publishers for select
  to authenticated, anon
  using (true);

drop policy if exists "Admin gestiona quien propone calendario" on public.calendar_contributors;
create policy "Admin gestiona quien propone calendario"
  on public.calendar_contributors for all
  to authenticated
  using (public.is_admin_user(auth.uid()))
  with check (public.is_admin_user(auth.uid()));

create or replace function public.is_calendar_contributor(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.calendar_contributors c
    join public.profiles p on p.id = c.profile_id
    where c.profile_id = p_user_id
      and p.suspended_at is null
  );
$$;

grant execute on function public.is_calendar_contributor(uuid) to authenticated, anon;

-- Admin publica al momento. Moderador o esta lista: el evento queda en revisión.
create or replace function public.can_submit_calendar_events(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_junta_member(p_user_id)
    or public.is_calendar_contributor(p_user_id);
$$;

-- Noticias al momento: admin, lista de noticias, lista de calendario o cualquier moderador.
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
     or public.is_news_publisher(new.author_id)
     or public.is_calendar_contributor(new.author_id)
     or public.is_junta_member(new.author_id) then
    new.status := 'published';
  else
    raise exception 'Solo la Junta puede publicar noticias';
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';
