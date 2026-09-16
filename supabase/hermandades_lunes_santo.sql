-- Cofradero · Hermandades: Lunes Santo (Sevilla)
-- Ejecutar después de hermandades_domingo_ramos.sql.

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status, created_at
) values
  (
    'lunes-santo-san-pablo', 'hermandades', '@cofradeo',
    'Lunes Santo · San Pablo',
    'Espacio para noticias, horarios, avisos e información oficial de San Pablo.',
    'Este es el espacio de seguimiento de San Pablo para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '10 minutes'
  ),
  (
    'lunes-santo-la-redencion', 'hermandades', '@cofradeo',
    'Lunes Santo · La Redención',
    'Espacio para noticias, horarios, avisos e información oficial de La Redención.',
    'Este es el espacio de seguimiento de La Redención para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '11 minutes'
  ),
  (
    'lunes-santo-santa-genoveva', 'hermandades', '@cofradeo',
    'Lunes Santo · Santa Genoveva',
    'Espacio para noticias, horarios, avisos e información oficial de Santa Genoveva.',
    'Este es el espacio de seguimiento de Santa Genoveva para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '12 minutes'
  ),
  (
    'lunes-santo-santa-marta', 'hermandades', '@cofradeo',
    'Lunes Santo · Santa Marta',
    'Espacio para noticias, horarios, avisos e información oficial de Santa Marta.',
    'Este es el espacio de seguimiento de Santa Marta para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '13 minutes'
  ),
  (
    'lunes-santo-san-gonzalo', 'hermandades', '@cofradeo',
    'Lunes Santo · San Gonzalo',
    'Espacio para noticias, horarios, avisos e información oficial de San Gonzalo.',
    'Este es el espacio de seguimiento de San Gonzalo para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '14 minutes'
  ),
  (
    'lunes-santo-vera-cruz', 'hermandades', '@cofradeo',
    'Lunes Santo · Vera Cruz',
    'Espacio para noticias, horarios, avisos e información oficial de Vera Cruz.',
    'Este es el espacio de seguimiento de Vera Cruz para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '15 minutes'
  ),
  (
    'lunes-santo-las-penas', 'hermandades', '@cofradeo',
    'Lunes Santo · Las Penas',
    'Espacio para noticias, horarios, avisos e información oficial de Las Penas.',
    'Este es el espacio de seguimiento de Las Penas para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '16 minutes'
  ),
  (
    'lunes-santo-las-aguas', 'hermandades', '@cofradeo',
    'Lunes Santo · Las Aguas',
    'Espacio para noticias, horarios, avisos e información oficial de Las Aguas.',
    'Este es el espacio de seguimiento de Las Aguas para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '17 minutes'
  ),
  (
    'lunes-santo-el-museo', 'hermandades', '@cofradeo',
    'Lunes Santo · El Museo',
    'Espacio para noticias, horarios, avisos e información oficial de El Museo.',
    'Este es el espacio de seguimiento de El Museo para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    false, 0, 0, 'published', now() - interval '18 minutes'
  )
on conflict (id) do nothing;

do $$
begin
  if to_regprocedure('public.refresh_forum_pillar_stats(text)') is not null then
    execute 'select public.refresh_forum_pillar_stats($1)' using 'hermandades';
  end if;
end;
$$;
