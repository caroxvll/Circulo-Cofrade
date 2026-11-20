-- El Cronicón: programar libro o artículo.
-- Ejecutar en SQL Editor (PRE y PROD).

alter table public.historias
  add column if not exists scheduled_at timestamptz;

alter table public.historias drop constraint if exists historias_status_check;
alter table public.historias
  add constraint historias_status_check
  check (status in ('published', 'hidden', 'draft', 'scheduled'));

create index if not exists historias_due_idx
  on public.historias (scheduled_at)
  where status = 'scheduled';

create or replace function public.publish_due_historias()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  update public.historias
  set
    status = 'published',
    updated_at = now()
  where status = 'scheduled'
    and scheduled_at is not null
    and scheduled_at <= now();
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on function public.publish_due_historias() to authenticated;

notify pgrst, 'reload schema';
