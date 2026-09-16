-- Cofradero · pilar Hermandades + Domingo de Ramos (Sevilla)
-- Ejecutar después de schema.sql y seed.sql.

insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active, locked_label
) values (
  'hermandades',
  'Hermandades',
  'Sigue las noticias y avisos de cada hermandad por día.',
  'groups_outlined',
  4,
  0,
  0,
  true,
  true,
  null
)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  icon_key = excluded.icon_key,
  sort_order = excluded.sort_order,
  is_enabled = excluded.is_enabled,
  is_active = excluded.is_active,
  locked_label = excluded.locked_label;

update public.forum_pillars
set sort_order = case id
  when 'semana-santa' then 5
  when 'cuaresma' then 6
  when 'glorias' then 7
  else sort_order
end
where id in ('semana-santa', 'cuaresma', 'glorias');

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status, created_at
) values
  (
    'domingo-ramos-la-borriquita', 'hermandades', '@cofradeo',
    'Domingo de Ramos · La Borriquita',
    'Espacio para noticias, horarios, avisos e información oficial de La Borriquita.',
    'Este es el espacio de seguimiento de La Borriquita para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '1 minute'
  ),
  (
    'domingo-ramos-la-cena', 'hermandades', '@cofradeo',
    'Domingo de Ramos · La Cena',
    'Espacio para noticias, horarios, avisos e información oficial de La Cena.',
    'Este es el espacio de seguimiento de La Cena para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '2 minutes'
  ),
  (
    'domingo-ramos-jesus-despojado', 'hermandades', '@cofradeo',
    'Domingo de Ramos · Jesús Despojado',
    'Espacio para noticias, horarios, avisos e información oficial de Jesús Despojado.',
    'Este es el espacio de seguimiento de Jesús Despojado para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '3 minutes'
  ),
  (
    'domingo-ramos-la-hiniesta', 'hermandades', '@cofradeo',
    'Domingo de Ramos · La Hiniesta',
    'Espacio para noticias, horarios, avisos e información oficial de La Hiniesta.',
    'Este es el espacio de seguimiento de La Hiniesta para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '4 minutes'
  ),
  (
    'domingo-ramos-la-paz', 'hermandades', '@cofradeo',
    'Domingo de Ramos · La Paz',
    'Espacio para noticias, horarios, avisos e información oficial de La Paz.',
    'Este es el espacio de seguimiento de La Paz para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '5 minutes'
  ),
  (
    'domingo-ramos-san-roque', 'hermandades', '@cofradeo',
    'Domingo de Ramos · San Roque',
    'Espacio para noticias, horarios, avisos e información oficial de San Roque.',
    'Este es el espacio de seguimiento de San Roque para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '6 minutes'
  ),
  (
    'domingo-ramos-la-estrella', 'hermandades', '@cofradeo',
    'Domingo de Ramos · La Estrella',
    'Espacio para noticias, horarios, avisos e información oficial de La Estrella.',
    'Este es el espacio de seguimiento de La Estrella para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '7 minutes'
  ),
  (
    'domingo-ramos-la-amargura', 'hermandades', '@cofradeo',
    'Domingo de Ramos · La Amargura',
    'Espacio para noticias, horarios, avisos e información oficial de La Amargura.',
    'Este es el espacio de seguimiento de La Amargura para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '8 minutes'
  ),
  (
    'domingo-ramos-el-amor', 'hermandades', '@cofradeo',
    'Domingo de Ramos · El Amor',
    'Espacio para noticias, horarios, avisos e información oficial de El Amor.',
    'Este es el espacio de seguimiento de El Amor para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '9 minutes'
  )
on conflict (id) do nothing;

-- Si tienes instalado sync_forum_pillar_stats.sql, recalcula contadores.
do $$
begin
  if to_regprocedure('public.refresh_forum_pillar_stats(text)') is not null then
    execute 'select public.refresh_forum_pillar_stats($1)' using 'hermandades';
  end if;
end;
$$;
