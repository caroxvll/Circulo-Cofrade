-- Cofradeo · author_handle denormalizado para Realtime (SS + ensayos)
-- Así el payload trae el @ sin pedir profiles. Idempotente.

-- Semana Santa
alter table public.ss_live_updates
  add column if not exists author_handle text not null default '';

update public.ss_live_updates u
set author_handle = coalesce(nullif(trim(p.handle), ''), 'cofrade')
from public.profiles p
where u.user_id = p.id
  and (u.author_handle is null or trim(u.author_handle) = '');

create or replace function public.ss_live_updates_set_author_handle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_handle text;
begin
  if new.author_handle is null or trim(new.author_handle) = '' then
    select nullif(trim(handle), '') into v_handle
    from public.profiles
    where id = new.user_id;
    new.author_handle := coalesce(v_handle, 'cofrade');
  else
    new.author_handle := trim(new.author_handle);
  end if;
  -- Normaliza sin @ inicial en BD; la app puede mostrar @handle
  if left(new.author_handle, 1) = '@' then
    new.author_handle := substr(new.author_handle, 2);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ss_live_updates_author_handle on public.ss_live_updates;
create trigger trg_ss_live_updates_author_handle
  before insert on public.ss_live_updates
  for each row
  execute function public.ss_live_updates_set_author_handle();

-- Ensayos Cuaresma
alter table public.event_live_updates
  add column if not exists author_handle text not null default '';

update public.event_live_updates u
set author_handle = coalesce(nullif(trim(p.handle), ''), 'cofrade')
from public.profiles p
where u.user_id = p.id
  and (u.author_handle is null or trim(u.author_handle) = '');

create or replace function public.event_live_updates_set_author_handle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_handle text;
begin
  if new.author_handle is null or trim(new.author_handle) = '' then
    select nullif(trim(handle), '') into v_handle
    from public.profiles
    where id = new.user_id;
    new.author_handle := coalesce(v_handle, 'cofrade');
  else
    new.author_handle := trim(new.author_handle);
  end if;
  if left(new.author_handle, 1) = '@' then
    new.author_handle := substr(new.author_handle, 2);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_event_live_updates_author_handle on public.event_live_updates;
create trigger trg_event_live_updates_author_handle
  before insert on public.event_live_updates
  for each row
  execute function public.event_live_updates_set_author_handle();

notify pgrst, 'reload schema';
