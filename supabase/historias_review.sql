-- El Cronicón: el cronista envía a revisión; admin/Junta publica.
-- Ejecutar en SQL Editor (PRE y PROD).

alter table public.historias
  add column if not exists review_note text;

alter table public.historias
  alter column status set default 'draft';

alter table public.historias drop constraint if exists historias_status_check;
alter table public.historias
  add constraint historias_status_check
  check (status in ('published', 'hidden', 'draft', 'scheduled', 'pending_review'));

create index if not exists historias_pending_review_idx
  on public.historias (updated_at desc)
  where status = 'pending_review';

create or replace function public.historias_guard_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if public.is_admin_user(auth.uid())
     or public.is_junta_member(auth.uid()) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('draft', 'pending_review') then
      raise exception 'Esta obra tiene que pasar por revisión antes de publicarse';
    end if;
    return new;
  end if;

  if new.status is distinct from old.status
     and new.status not in ('draft', 'pending_review') then
    raise exception 'Esta obra tiene que pasar por revisión antes de publicarse';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_historias_guard_review on public.historias;
create trigger trg_historias_guard_review
  before insert or update on public.historias
  for each row execute function public.historias_guard_review();

drop policy if exists "Historias publicadas legibles" on public.historias;
create policy "Historias publicadas legibles"
  on public.historias for select
  to authenticated
  using (
    status = 'published'
    or author_id = auth.uid()
    or public.is_junta_member(auth.uid())
    or public.is_admin_user(auth.uid())
  );

notify pgrst, 'reload schema';
