-- Temporada por hermandad: pasos juntos o no, nº de ensayos, muda/retranqueo.
-- Ejecutar en SQL Editor (PRE y PROD).

alter table public.calendar_events
  add column if not exists paso text not null default 'ambos';

alter table public.calendar_events
  drop constraint if exists calendar_events_paso_check;
alter table public.calendar_events
  add constraint calendar_events_paso_check
  check (paso in ('ambos', 'cristo', 'virgen'));

alter table public.calendar_events
  add column if not exists season_n int;

alter table public.calendar_events
  drop constraint if exists calendar_events_season_n_check;
alter table public.calendar_events
  add constraint calendar_events_season_n_check
  check (season_n is null or season_n between 1 and 12);

alter table public.calendar_events
  add column if not exists with_retranqueo boolean not null default false;

comment on column public.calendar_events.paso is
  'Paso del acto: ambos, cristo o virgen.';
comment on column public.calendar_events.season_n is
  'Número de ensayo (1º, 2º…). Null si no aplica.';
comment on column public.calendar_events.with_retranqueo is
  'La muda incluye retranqueo el mismo día.';

create table if not exists public.hermandad_season_profile (
  topic_id text primary key references public.forum_topics (id) on delete cascade,
  iguala_split boolean not null default false,
  ensayo_split boolean not null default false,
  ensayo_count int not null default 1
    check (ensayo_count between 1 and 12),
  muda_mode text not null default 'muda_only'
    check (muda_mode in ('with_retranqueo', 'split', 'muda_only')),
  updated_at timestamptz not null default now()
);

comment on table public.hermandad_season_profile is
  'Cómo monta cada hermandad la temporada: igualá/ensayos por paso y muda/retranqueo.';

alter table public.hermandad_season_profile enable row level security;

drop policy if exists "Lee perfil de temporada" on public.hermandad_season_profile;
create policy "Lee perfil de temporada"
  on public.hermandad_season_profile for select
  to authenticated
  using (true);

drop policy if exists "Escribe perfil de temporada" on public.hermandad_season_profile;
create policy "Escribe perfil de temporada"
  on public.hermandad_season_profile for insert
  to authenticated
  with check (
    public.is_admin_user(auth.uid())
    or public.is_junta_member(auth.uid())
    or public.is_hermandad_board_manager(auth.uid(), topic_id)
  );

drop policy if exists "Actualiza perfil de temporada" on public.hermandad_season_profile;
create policy "Actualiza perfil de temporada"
  on public.hermandad_season_profile for update
  to authenticated
  using (
    public.is_admin_user(auth.uid())
    or public.is_junta_member(auth.uid())
    or public.is_hermandad_board_manager(auth.uid(), topic_id)
  )
  with check (
    public.is_admin_user(auth.uid())
    or public.is_junta_member(auth.uid())
    or public.is_hermandad_board_manager(auth.uid(), topic_id)
  );

grant select, insert, update on public.hermandad_season_profile to authenticated;

-- Posts programados: paso, nº de ensayo y muda+retranqueo al publicar el evento.
alter table public.hermandad_scheduled_posts
  add column if not exists calendar_paso text;

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_calendar_paso_check;
alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_calendar_paso_check
  check (calendar_paso is null or calendar_paso in ('ambos', 'cristo', 'virgen'));

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_season_n int;

alter table public.hermandad_scheduled_posts
  drop constraint if exists hermandad_scheduled_posts_calendar_season_n_check;
alter table public.hermandad_scheduled_posts
  add constraint hermandad_scheduled_posts_calendar_season_n_check
  check (calendar_season_n is null or calendar_season_n between 1 and 12);

alter table public.hermandad_scheduled_posts
  add column if not exists calendar_with_retranqueo boolean not null default false;

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
  v_title text;
  v_organizer text;
  v_icon text;
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
      official_category,
      image_url
    ) values (
      v_row.topic_id,
      v_row.author_id,
      v_row.author_handle,
      v_row.content,
      true,
      v_row.official_category,
      v_row.image_url
    )
    returning id into v_reply_id;

    if v_row.calendar_event_type is not null
       and v_row.calendar_starts_at is not null then
      v_title := nullif(trim(coalesce(v_row.calendar_title, '')), '');
      if v_title is null then
        v_title := nullif(
          trim(substring(v_row.content from '^\*\*(.+?)\*\*')),
          ''
        );
      end if;
      if v_title is null then
        v_title := left(regexp_replace(v_row.content, '\s+', ' ', 'g'), 80);
      end if;

      v_organizer := nullif(trim(coalesce(v_row.calendar_organizer_label, '')), '');
      if v_organizer is null then
        select coalesce(nullif(trim(p.display_name), ''), 'Hermandad')
        into v_organizer
        from public.profiles p
        where p.id = v_row.author_id;
      end if;

      v_icon := nullif(trim(coalesce(v_row.calendar_custom_icon_url, '')), '');
      if v_icon is null then
        select nullif(trim(t.icon_image_url), '')
        into v_icon
        from public.forum_topics t
        where t.id = v_row.topic_id;
      end if;

      insert into public.calendar_events (
        title,
        subtitle,
        event_type,
        starts_at,
        location,
        organizer_label,
        cover_image_url,
        custom_icon_url,
        created_by,
        status,
        source_reply_id,
        hermandad_topic_id,
        paso,
        season_n,
        with_retranqueo
      ) values (
        left(v_title, 120),
        left(coalesce(v_organizer, 'Hermandad'), 240),
        v_row.calendar_event_type,
        v_row.calendar_starts_at,
        left(coalesce(v_row.calendar_location, ''), 160),
        left(coalesce(v_organizer, 'Hermandad'), 120),
        left(coalesce(v_row.calendar_cover_image_url, v_row.image_url, ''), 700),
        left(coalesce(v_icon, ''), 700),
        v_row.author_id,
        'published',
        v_reply_id,
        v_row.topic_id,
        coalesce(v_row.calendar_paso, 'ambos'),
        v_row.calendar_season_n,
        coalesce(v_row.calendar_with_retranqueo, false)
      );
    end if;

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

notify pgrst, 'reload schema';
