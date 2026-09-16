-- Cofradeo · borradores en publicaciones de hermandades
-- Solo si aplicaste hermandad_scheduled_posts.sql ANTES de que incluyera borradores.
-- Si vuelves a ejecutar el SQL principal actualizado, NO hace falta este archivo.

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
