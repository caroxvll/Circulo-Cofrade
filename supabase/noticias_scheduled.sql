-- Cofradero · Noticias programadas (canal editorial)
-- Ejecutar después de noticias_forum.sql / noticias_related_forum.sql

create table if not exists public.noticias_scheduled (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_handle text not null,
  title text not null check (char_length(trim(title)) between 2 and 160),
  excerpt text not null default '',
  body text not null check (char_length(trim(body)) between 1 and 20000),
  cover_image_url text,
  related_forum_id text references public.forum_pillars (id) on delete set null,
  scheduled_at timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'published', 'cancelled')),
  published_topic_id text references public.forum_topics (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint noticias_scheduled_related_check
    check (
      related_forum_id is null
      or related_forum_id in (
        'foro-cofradiero',
        'pentagrama-cofrade',
        'martillo-trabajadera',
        'hermandades'
      )
    )
);

create index if not exists noticias_scheduled_due_idx
  on public.noticias_scheduled (scheduled_at)
  where status = 'scheduled';

create index if not exists noticias_scheduled_list_idx
  on public.noticias_scheduled (status, scheduled_at desc);

alter table public.noticias_scheduled enable row level security;

create or replace function public.can_manage_noticias(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_admin_user(p_user_id)
    or exists (
      select 1
      from public.forum_moderators fm
      where fm.profile_id = p_user_id
        and fm.forum_id = 'noticias'
    );
$$;

grant execute on function public.can_manage_noticias(uuid) to authenticated;

drop policy if exists "Staff lee noticias programadas" on public.noticias_scheduled;
create policy "Staff lee noticias programadas"
  on public.noticias_scheduled for select
  using (public.can_manage_noticias(auth.uid()));

drop policy if exists "Staff programa noticias" on public.noticias_scheduled;
create policy "Staff programa noticias"
  on public.noticias_scheduled for insert
  with check (
    author_id = auth.uid()
    and public.can_manage_noticias(auth.uid())
    and status = 'scheduled'
    and scheduled_at > now() + interval '2 minutes'
  );

drop policy if exists "Staff edita noticias programadas" on public.noticias_scheduled;
create policy "Staff edita noticias programadas"
  on public.noticias_scheduled for update
  using (
    public.can_manage_noticias(auth.uid())
    and status = 'scheduled'
  )
  with check (
    public.can_manage_noticias(auth.uid())
    and (
      status = 'cancelled'
      or (
        status = 'scheduled'
        and scheduled_at > now() + interval '2 minutes'
      )
    )
  );

drop policy if exists "Staff borra noticias programadas" on public.noticias_scheduled;
create policy "Staff borra noticias programadas"
  on public.noticias_scheduled for delete
  using (
    public.can_manage_noticias(auth.uid())
    and status in ('scheduled', 'cancelled')
  );

create or replace function public.noticias_topic_id_from_title(p_title text)
returns text
language plpgsql
as $$
declare
  v_slug text;
  v_suffix text;
begin
  v_slug := lower(trim(p_title));
  v_slug := translate(
    v_slug,
    'áàäâãéèëêíìïîóòöôõúùüûñ',
    'aaaaaeeeeiiiiooooouuuun'
  );
  v_slug := regexp_replace(v_slug, '[^a-z0-9]+', '-', 'g');
  v_slug := regexp_replace(v_slug, '^-+|-+$', '', 'g');
  if v_slug = '' then
    v_slug := 'noticia';
  end if;
  if char_length(v_slug) > 40 then
    v_slug := left(v_slug, 40);
  end if;
  v_suffix := to_hex((extract(epoch from clock_timestamp()) * 1000)::bigint);
  return v_slug || '-' || v_suffix;
end;
$$;

create or replace function public.publish_due_noticias_scheduled()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.noticias_scheduled%rowtype;
  v_topic_id text;
  v_count integer := 0;
  v_excerpt text;
begin
  for v_row in
    select *
    from public.noticias_scheduled
    where status = 'scheduled'
      and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    v_excerpt := nullif(trim(v_row.excerpt), '');
    if v_excerpt is null then
      v_excerpt := left(trim(v_row.body), 180);
    end if;

    v_topic_id := public.noticias_topic_id_from_title(v_row.title);

    insert into public.forum_topics (
      id,
      forum_id,
      author_id,
      author_handle,
      title,
      excerpt,
      body,
      cover_image_url,
      related_forum_id,
      status
    ) values (
      v_topic_id,
      'noticias',
      v_row.author_id,
      v_row.author_handle,
      trim(v_row.title),
      v_excerpt,
      trim(v_row.body),
      v_row.cover_image_url,
      v_row.related_forum_id,
      'pending'
    );

    update public.noticias_scheduled
    set status = 'published',
        published_topic_id = v_topic_id,
        updated_at = now()
    where id = v_row.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.publish_due_noticias_scheduled() to authenticated;

-- Opcional (pg_cron):
-- select cron.schedule(
--   'publish-noticias-scheduled',
--   '* * * * *',
--   $$ select public.publish_due_noticias_scheduled(); $$
-- );
