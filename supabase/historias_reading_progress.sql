-- El Cronicón: dónde se quedó cada cofrade en un libro o artículo.
-- Ejecutar en SQL Editor (PRE y PROD).

create table if not exists public.historia_reading_progress (
  user_id uuid not null references public.profiles (id) on delete cascade,
  historia_id uuid not null references public.historias (id) on delete cascade,
  page int not null default 0 check (page >= 0),
  page_count int not null default 1 check (page_count >= 1),
  updated_at timestamptz not null default now(),
  primary key (user_id, historia_id)
);

comment on table public.historia_reading_progress is
  'Marca de lectura por usuario y obra. page es el índice del page-flip (0 = portada).';

create index if not exists historia_reading_progress_user_idx
  on public.historia_reading_progress (user_id, updated_at desc);

alter table public.historia_reading_progress enable row level security;

drop policy if exists "Lee su marca de lectura" on public.historia_reading_progress;
create policy "Lee su marca de lectura"
  on public.historia_reading_progress for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Guarda su marca de lectura" on public.historia_reading_progress;
create policy "Guarda su marca de lectura"
  on public.historia_reading_progress for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Actualiza su marca de lectura" on public.historia_reading_progress;
create policy "Actualiza su marca de lectura"
  on public.historia_reading_progress for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Borra su marca de lectura" on public.historia_reading_progress;
create policy "Borra su marca de lectura"
  on public.historia_reading_progress for delete
  to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete
  on public.historia_reading_progress to authenticated;

notify pgrst, 'reload schema';
