-- Cofradeo · publicaciones programadas en tablones de hermandades
-- Ejecutar después de hermandad_official_posts.sql

create table if not exists public.hermandad_scheduled_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  author_handle text not null,
  topic_id text not null references public.forum_topics (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  official_category text not null default 'noticia'
    check (official_category in ('noticia', 'culto', 'acto', 'patrimonio')),
  scheduled_at timestamptz,
  status text not null default 'scheduled'
    check (status in ('draft', 'scheduled', 'published', 'cancelled')),
  published_reply_id uuid references public.forum_replies (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Idempotente: aplicar también si la tabla ya existía (versión sin borradores).
alter table public.hermandad_scheduled_posts
  alter column scheduled_at drop not null;

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_status_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_status_check
  check (status in ('draft', 'scheduled', 'published', 'cancelled'));

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_scheduled_at_check;

alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_scheduled_at_check
  check (
    (status = 'draft' and scheduled_at is null)
    or (status in ('scheduled', 'published', 'cancelled') and scheduled_at is not null)
  );

create index if not exists hermandad_scheduled_posts_due_idx
  on public.hermandad_scheduled_posts (scheduled_at)
  where status = 'scheduled';

create index if not exists hermandad_scheduled_posts_author_idx
  on public.hermandad_scheduled_posts (author_id, status, scheduled_at desc);

alter table public.hermandad_scheduled_posts enable row level security;

drop policy if exists "Autor lee sus publicaciones programadas" on public.hermandad_scheduled_posts;
create policy "Autor lee sus publicaciones programadas"
  on public.hermandad_scheduled_posts for select
  using (
    author_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role in ('admin', 'moderator')
        and p.suspended_at is null
    )
  );

drop policy if exists "Hermandad programa publicaciones oficiales" on public.hermandad_scheduled_posts;
create policy "Hermandad programa publicaciones oficiales"
  on public.hermandad_scheduled_posts for insert
  with check (
    author_id = auth.uid()
    and public.can_create_official_hermandad_post(auth.uid(), topic_id)
    and (
      (
        status = 'draft'
        and scheduled_at is null
      )
      or (
        status = 'scheduled'
        and scheduled_at is not null
        and scheduled_at > now() + interval '5 minutes'
      )
    )
  );

drop policy if exists "Autor edita publicaciones programadas pendientes" on public.hermandad_scheduled_posts;
create policy "Autor edita publicaciones programadas pendientes"
  on public.hermandad_scheduled_posts for update
  using (
    author_id = auth.uid()
    and status in ('draft', 'scheduled')
  )
  with check (
    author_id = auth.uid()
    and public.can_create_official_hermandad_post(auth.uid(), topic_id)
    and (
      status = 'cancelled'
      or (
        status = 'draft'
        and scheduled_at is null
      )
      or (
        status = 'scheduled'
        and scheduled_at is not null
        and scheduled_at > now() + interval '5 minutes'
      )
    )
  );

drop policy if exists "Autor elimina borradores" on public.hermandad_scheduled_posts;
create policy "Autor elimina borradores"
  on public.hermandad_scheduled_posts for delete
  using (
    author_id = auth.uid()
    and status = 'draft'
  );

create index if not exists hermandad_scheduled_posts_drafts_idx
  on public.hermandad_scheduled_posts (author_id, updated_at desc)
  where status = 'draft';

create or replace function public.publish_due_hermandad_scheduled_posts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_reply_id uuid;
  v_count integer := 0;
begin
  for v_row in
    select *
    from public.hermandad_scheduled_posts
    where status = 'scheduled'
      and scheduled_at <= now()
    order by scheduled_at
    for update skip locked
  loop
    insert into public.forum_replies (
      topic_id,
      author_id,
      author_handle,
      content,
      is_official,
      official_category
    ) values (
      v_row.topic_id,
      v_row.author_id,
      v_row.author_handle,
      v_row.content,
      true,
      v_row.official_category
    )
    returning id into v_reply_id;

    update public.hermandad_scheduled_posts
    set status = 'published',
        published_reply_id = v_reply_id,
        updated_at = now()
    where id = v_row.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.publish_due_hermandad_scheduled_posts() to authenticated;

-- Opcional (pg_cron en Supabase): publicar cada minuto
-- select cron.schedule(
--   'publish-hermandad-scheduled-posts',
--   '* * * * *',
--   $$ select public.publish_due_hermandad_scheduled_posts(); $$
-- );
