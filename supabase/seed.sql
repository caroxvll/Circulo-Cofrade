-- Cofradero · datos iniciales (ejecutar DESPUÉS de schema.sql)
-- Pilares, temas y respuestas equivalentes a los mocks de la app.

insert into public.forum_pillars (
  id, name, description, icon_key, sort_order,
  topic_count, message_count, is_enabled, is_active, locked_label
) values
  ('foro-cofradiero', 'Foro Cofradiero', 'El lugar de encuentro para todos los cofrades.', 'church', 1, 0, 0, true, true, null),
  ('pentagrama-cofrade', 'Pentagrama Cofrade', 'La música que acompaña nuestra Semana Santa.', 'music_note', 2, 0, 0, true, false, null),
  ('martillo-trabajadera', 'Martillo y Trabajadera', 'El arte de la talla, el bordado y la orfebrería.', 'workspace_premium_outlined', 3, 0, 0, true, false, null),
  ('semana-santa', 'Semana Santa', 'Todo sobre la Semana Mayor: procesiones, horarios y noticias.', 'account_balance', 4, 0, 0, false, false, 'Se activará en Semana Santa'),
  ('cuaresma', 'Cuaresma', 'Cultos, estaciones, pregones y camino hacia la Semana Mayor.', 'filter_vintage_outlined', 5, 0, 0, false, false, 'Se activará en Cuaresma'),
  ('glorias', 'Glorias', 'Procesiones de gloria, Domingo de Resurrección y cultos de gloria.', 'wb_sunny_outlined', 6, 0, 0, false, false, 'Se activará en tiempo de Glorias')
on conflict (id) do nothing;

insert into public.forum_topics (
  id, forum_id, author_handle, title, excerpt, body,
  is_resolved, view_count, comment_count, status, created_at
) values
  (
    'nueva-ruta-viernes-santo', 'foro-cofradiero', '@cofrade_senior',
    'Nueva ruta de la procesión del Viernes Santo',
    'Os comunicamos que este año la procesión pasará por Plaza Mayor a las 18:30. ¿Qué os parece el nuevo itinerario?',
    'Queridos cofrades, os comunicamos que este año la procesión del Viernes Santo seguirá un nuevo itinerario que pasará por Plaza Mayor a las 18:30, antes de continuar hacia la Catedral.\n\nEl recorrido ha sido acordado con el Consejo de Hermandades y busca facilitar el acceso de los fieles sin perder la tradición del paso por los puntos más emblemáticos del centro.\n\n¿Qué os parece el cambio? Dejad vuestras opiniones y dudas.',
    true, 0, 0, 'published', now() - interval '2 hours'
  ),
  (
    'horarios-iguala-costaleros', 'foro-cofradiero', '@jose_carpintero',
    'Horarios de la iguala de costaleros',
    '¿Alguien sabe a qué hora empieza la iguala este sábado en la casa de hermandad?',
    'Buenas tardes. ¿Alguien sabe a qué hora empieza la iguala de costaleros este sábado en la casa de hermandad? Gracias de antemano.',
    false, 0, 0, 'published', now() - interval '4 hours'
  ),
  (
    'banda-procesion-misericordia', 'foro-cofradiero', '@maria_dolores',
    'Banda de la procesión de la Misericordia',
    'Confirmado el repertorio: Marcha Negra y Amarguras. Ensayo general el jueves.',
    'Confirmado el repertorio para la procesión: Marcha Negra y Amarguras. Ensayo general el jueves a las 21:00 en el patio de la sede.',
    false, 0, 0, 'published', now() - interval '6 hours'
  ),
  (
    'tunica-nuevo-modelo', 'foro-cofradiero', '@hermandad_sevilla',
    'Nuevo modelo de túnica para nazarenos',
    'La hermandad presenta el diseño preliminar. Votación abierta hasta el domingo.',
    'La hermandad presenta el diseño preliminar de la nueva túnica para nazarenos. Votación abierta hasta el domingo en la sede y en este hilo.',
    false, 0, 0, 'published', now() - interval '1 day'
  ),
  (
    'itinerario-extraordinario', 'foro-cofradiero', '@cofrade_senior',
    'Itinerario extraordinario por obras en el centro',
    'Desvío temporal por calle Sierpes. Mapa adjunto en el hilo.',
    'Por las obras en el centro histórico habrá un desvío temporal por calle Sierpes. Adjuntamos mapa con el recorrido alternativo acordado.',
    false, 0, 0, 'published', now() - interval '2 days'
  )
on conflict (id) do nothing;

insert into public.forum_replies (
  id, topic_id, author_handle, content, like_count, created_at
) values
  (
    '00000000-0000-4000-8000-000000000001',
    'nueva-ruta-viernes-santo', '@jose_carpintero',
    '¿Sabe alguien qué banda acompañará a la procesión este año? En el tramo de Plaza Mayor me gustaría escuchar las marchas.',
    24, now() - interval '1 hour'
  ),
  (
    '00000000-0000-4000-8000-000000000002',
    'nueva-ruta-viernes-santo', '@maria_dolores',
    'Muchas gracias por la información, @cofrade_senior. El nuevo itinerario me parece muy acertado para agilizar el paso.',
    31, now() - interval '45 minutes'
  )
on conflict (id) do nothing;
