-- Cofradeo · Historias (ebooks). Apartado apagado hasta que la Junta lo encienda.
-- Idempotente. Ejecutar en SQL Editor (PRE/PROD).

alter table public.profiles
  add column if not exists is_chronicler boolean not null default false;

comment on column public.profiles.is_chronicler is
  'Cronista: puede publicar en Historias. Lo marca el admin, no es la cuenta verificada.';

create or replace function public.is_chronicler(p_user_id uuid)
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
      and is_chronicler = true
      and suspended_at is null
  );
$$;

create or replace function public.can_publish_historia(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_chronicler(p_user_id)
      or public.is_admin_user(p_user_id);
$$;

create or replace function public.prevent_profile_chronicler_self_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_chronicler is distinct from old.is_chronicler
     and auth.uid() is not null
     and auth.uid() = old.id
     and not public.is_admin_user(auth.uid()) then
    raise exception 'No puedes cambiar tu sello de cronista';
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_chronicler_guard on public.profiles;
create trigger on_profile_chronicler_guard
  before update on public.profiles
  for each row execute function public.prevent_profile_chronicler_self_change();

insert into public.app_config (key, value)
values ('historias_hub', 'off')
on conflict (key) do nothing;

create table if not exists public.historias (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 80),
  excerpt text not null default '' check (char_length(excerpt) <= 280),
  cover_image_url text,
  kind text not null default 'cronica'
    check (kind in ('libro', 'anecdota', 'cronica')),
  pages jsonb not null
    check (
      jsonb_typeof(pages) = 'array'
      and jsonb_array_length(pages) between 1 and 30
    ),
  status text not null default 'published'
    check (status in ('published', 'hidden', 'draft')),
  comment_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists historias_published_idx
  on public.historias (created_at desc)
  where status = 'published';

create table if not exists public.historia_comments (
  id uuid primary key default gen_random_uuid(),
  historia_id uuid not null references public.historias (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists historia_comments_historia_idx
  on public.historia_comments (historia_id, created_at desc);

create or replace function public.historias_touch_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.historias
    set comment_count = comment_count + 1
    where id = new.historia_id;
    return new;
  end if;
  if tg_op = 'DELETE' then
    update public.historias
    set comment_count = greatest(comment_count - 1, 0)
    where id = old.historia_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_historia_comments_count on public.historia_comments;
create trigger trg_historia_comments_count
  after insert or delete on public.historia_comments
  for each row execute function public.historias_touch_comment_count();

alter table public.historias enable row level security;
alter table public.historia_comments enable row level security;

drop policy if exists "Historias publicadas legibles" on public.historias;
create policy "Historias publicadas legibles"
  on public.historias for select
  to authenticated
  using (
    status = 'published'
    or author_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Cronista publica historia" on public.historias;
create policy "Cronista publica historia"
  on public.historias for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.can_publish_historia(auth.uid())
  );

drop policy if exists "Autor o Junta edita historia" on public.historias;
create policy "Autor o Junta edita historia"
  on public.historias for update
  to authenticated
  using (
    author_id = auth.uid()
    or public.is_junta_member(auth.uid())
  )
  with check (
    author_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Autor o Junta borra historia" on public.historias;
create policy "Autor o Junta borra historia"
  on public.historias for delete
  to authenticated
  using (
    author_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

drop policy if exists "Comentarios de historia legibles" on public.historia_comments;
create policy "Comentarios de historia legibles"
  on public.historia_comments for select
  to authenticated
  using (true);

drop policy if exists "Cofrade comenta historia" on public.historia_comments;
create policy "Cofrade comenta historia"
  on public.historia_comments for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Autor o Junta borra comentario de historia"
  on public.historia_comments;
create policy "Autor o Junta borra comentario de historia"
  on public.historia_comments for delete
  to authenticated
  using (
    user_id = auth.uid()
    or public.is_junta_member(auth.uid())
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'historia-covers',
  'historia-covers',
  true,
  3145728,
  array['image/png', 'image/webp', 'image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Portadas historia lectura" on storage.objects;
create policy "Portadas historia lectura"
  on storage.objects for select
  using (bucket_id = 'historia-covers');

drop policy if exists "Cronista sube portada historia" on storage.objects;
create policy "Cronista sube portada historia"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'historia-covers'
    and public.can_publish_historia(auth.uid())
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Cronista actualiza portada historia" on storage.objects;
create policy "Cronista actualiza portada historia"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'historia-covers'
    and (
      public.can_publish_historia(auth.uid())
      and (storage.foldername(name))[1] = auth.uid()::text
      or public.is_junta_member(auth.uid())
    )
  );

grant select, insert, update, delete on public.historias to authenticated;
grant select, insert, delete on public.historia_comments to authenticated;
grant execute on function public.is_chronicler(uuid) to authenticated;
grant execute on function public.can_publish_historia(uuid) to authenticated;

-- Si ya se ejecutó una versión con pages text[]: pasar a jsonb con fotos.
-- ALTER ... USING no admite subconsultas; to_jsonb(text[]) sí.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'historias'
      and column_name = 'pages'
      and udt_name = '_text'
  ) then
    alter table public.historias drop constraint if exists historias_pages_check;
    alter table public.historias
      alter column pages type jsonb using to_jsonb(pages);
  end if;
end $$;

update public.historias
set pages = coalesce((
  select jsonb_agg(jsonb_build_object('body', elem))
  from jsonb_array_elements_text(pages) as elem
), '[]'::jsonb)
where jsonb_typeof(pages) = 'array'
  and exists (
    select 1
    from jsonb_array_elements(pages) as e
    where jsonb_typeof(e.value) = 'string'
  );

alter table public.historias drop constraint if exists historias_pages_check;
alter table public.historias
  add constraint historias_pages_check
  check (
    jsonb_typeof(pages) = 'array'
    and jsonb_array_length(pages) between 1 and 30
  );

alter table public.historias
  add column if not exists kind text not null default 'cronica';

alter table public.historias drop constraint if exists historias_kind_check;
alter table public.historias
  add constraint historias_kind_check
  check (kind in ('libro', 'anecdota', 'cronica'));

alter table public.historias drop constraint if exists historias_status_check;
alter table public.historias
  add constraint historias_status_check
  check (status in ('published', 'hidden', 'draft'));

notify pgrst, 'reload schema';
