-- Cofradero · Temas fijos (pinned) dentro de pilares + ocultar pilares de temporada
-- Ejecutar después de schema.sql. Idempotente.

alter table public.forum_topics
  add column if not exists is_pinned boolean not null default false;

alter table public.forum_topics
  add column if not exists pin_sort_order int not null default 0;

alter table public.forum_topics
  add column if not exists is_system boolean not null default false;

alter table public.forum_topics
  add column if not exists season_key text
    check (
      season_key is null
      or season_key in ('cuaresma', 'semana_santa', 'glorias')
    );

alter table public.forum_topics
  add column if not exists icon_key text;

alter table public.forum_topics
  add column if not exists cover_image_url text;

create index if not exists forum_topics_pinned_idx
  on public.forum_topics (forum_id, is_pinned, pin_sort_order);

-- Los pilares de temporada pasan a temas fijos dentro del Círculo Cofrade.
update public.forum_pillars
set is_enabled = false
where id in ('cuaresma', 'glorias', 'semana-santa');

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status,
  is_pinned, pin_sort_order, is_system, season_key, icon_key, created_at
) values
  (
    'circulo-cuaresma', 'foro-cofradiero', '@cofradeo',
    'Cuaresma',
    'Cultos, estaciones, pregones y camino hacia la Semana Mayor.',
    'Espacio para hablar de la Cuaresma: cultos, estaciones de penitencia, pregones, cartelería y camino hacia la Semana Mayor.\n\nComparte noticias, dudas y conversación con la comunidad cofrade.',
    false, 0, 0, 'published',
    true, 1, true, 'cuaresma', 'filter_vintage_outlined', now() - interval '30 days'
  ),
  (
    'circulo-semana-santa', 'foro-cofradiero', '@cofradeo',
    'Semana Santa',
    'Todo sobre la Semana Mayor: procesiones, horarios y noticias.',
    'El hilo de la Semana Mayor: procesiones, horarios, itinerarios, avisos y noticias de las jornadas grandes.\n\nCentraliza aquí la conversación cofrade de la Semana Santa en Sevilla.',
    false, 0, 0, 'published',
    true, 2, true, 'semana_santa', 'account_balance', now() - interval '29 days'
  ),
  (
    'circulo-glorias', 'foro-cofradiero', '@cofradeo',
    'Glorias',
    'Procesiones de gloria, Domingo de Resurrección y cultos de gloria.',
    'Todo sobre el tiempo de Glorias: Domingo de Resurrección, procesiones de gloria, cultos y la actualidad cofrade después de la Semana Mayor.\n\nComparte noticias, horarios y conversación con la comunidad.',
    false, 0, 0, 'published',
    true, 3, true, 'glorias', 'wb_sunny_outlined', now() - interval '28 days'
  ),
  (
    'martillo-cambio-capataces', 'martillo-trabajadera', '@cofradeo',
    'Cambio de capataces',
    'Rumores, confirmaciones y actualidad de traslados de capataces.',
    'Espacio permanente para la actualidad del costal: cambios de capataces, traslados, nombres que suenan y confirmaciones oficiales.\n\nComparte rumores con respeto y contrasta siempre con fuentes fiables.',
    false, 0, 0, 'published',
    true, 1, true, null, 'workspace_premium_outlined', now() - interval '27 days'
  )
on conflict (id) do update set
  forum_id = excluded.forum_id,
  title = excluded.title,
  excerpt = excluded.excerpt,
  body = excluded.body,
  status = excluded.status,
  is_pinned = excluded.is_pinned,
  pin_sort_order = excluded.pin_sort_order,
  is_system = excluded.is_system,
  season_key = excluded.season_key,
  icon_key = excluded.icon_key;

do $$
begin
  if to_regprocedure('public.refresh_forum_pillar_stats(text)') is not null then
    execute 'select public.refresh_forum_pillar_stats($1)' using 'foro-cofradiero';
    execute 'select public.refresh_forum_pillar_stats($1)' using 'martillo-trabajadera';
  end if;
end;
$$;
