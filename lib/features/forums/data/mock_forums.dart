import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/forum.dart';
import '../utils/topic_list_order.dart';

final _countFormat = NumberFormat('#,###', 'es');

final mockForumCategories = <ForumCategory>[
  const ForumCategory(
    id: 'noticias',
    name: 'Noticias',
    description: 'Última hora de la Semana Santa de Sevilla.',
    icon: Icons.newspaper_outlined,
    sortOrder: 0,
    topicCount: 0,
    messageCount: 0,
    lastMessageAgo: 'sin actividad',
    isEnabled: true,
    isActive: true,
  ),
  const ForumCategory(
    id: 'foro-cofradiero',
    name: 'Círculo Cofrade',
    description: 'La tertulia cofrade de Sevilla, los 365 días del año.',
    icon: Icons.church,
    sortOrder: 1,
    topicCount: 8,
    messageCount: 2,
    lastMessageAgo: 'hace 45 min',
    lastTopicId: 'nueva-ruta-viernes-santo',
    lastTopicTitle: 'Nueva ruta de la procesión del Viernes Santo',
    isEnabled: true,
    isActive: true,
  ),
  const ForumCategory(
    id: 'pentagrama-cofrade',
    name: 'Pentagrama Cofrade',
    description:
        'Agrupaciones, cornetas y tambores, bandas de música y repertorios.',
    icon: Icons.music_note,
    sortOrder: 2,
    topicCount: 0,
    messageCount: 0,
    lastMessageAgo: 'sin actividad',
    isEnabled: true,
    isActive: false,
  ),
  const ForumCategory(
    id: 'martillo-trabajadera',
    name: 'Martillo y Trabajadera',
    description: 'La actualidad de los capataces y el mundo del costal.',
    icon: Icons.workspace_premium_outlined,
    sortOrder: 3,
    topicCount: 1,
    messageCount: 0,
    lastMessageAgo: 'sin actividad',
    isEnabled: true,
    isActive: true,
  ),
  const ForumCategory(
    id: 'hermandades',
    name: 'Hermandades',
    description:
        'Canal oficial de noticias, cultos, actos y patrimonio. Solo lectura.',
    icon: Icons.groups_outlined,
    sortOrder: 4,
    topicCount: 72,
    messageCount: 0,
    lastMessageAgo: 'sin actividad',
    lastTopicId: 'domingo-ramos-la-borriquita',
    lastTopicTitle: 'Domingo de Ramos · La Borriquita',
    isEnabled: true,
    isActive: true,
  ),
  const ForumCategory(
    id: 'semana-santa',
    name: 'Semana Santa',
    description:
        'Todo sobre la Semana Mayor: procesiones, horarios y noticias.',
    icon: Icons.account_balance,
    sortOrder: 5,
    topicCount: 0,
    messageCount: 0,
    lastMessageAgo: '—',
    isEnabled: false,
    isActive: false,
    lockedLabel: 'Se activará en Semana Santa',
  ),
  const ForumCategory(
    id: 'cuaresma',
    name: 'Cuaresma',
    description: 'Cultos, estaciones, pregones y camino hacia la Semana Mayor.',
    icon: Icons.filter_vintage_outlined,
    sortOrder: 6,
    topicCount: 0,
    messageCount: 0,
    lastMessageAgo: '—',
    isEnabled: false,
    isActive: false,
    lockedLabel: 'Se activará en Cuaresma',
  ),
  const ForumCategory(
    id: 'glorias',
    name: 'Glorias',
    description:
        'Procesiones de gloria, Domingo de Resurrección y cultos de gloria.',
    icon: Icons.wb_sunny_outlined,
    sortOrder: 7,
    topicCount: 0,
    messageCount: 0,
    lastMessageAgo: '—',
    isEnabled: false,
    isActive: false,
    lockedLabel: 'Se activará en tiempo de Glorias',
  ),
];

/// Pilares visibles en lista, ordenados por prioridad (`sortOrder`).
List<ForumCategory> get visibleForumCategories {
  return visibleForumPillars(mockForumCategories);
}

ForumCategory? forumById(String id) {
  try {
    return mockForumCategories.firstWhere((f) => f.id == id);
  } catch (_) {
    return null;
  }
}

bool canAccessForum(String id) {
  final forum = forumById(id);
  return forum != null && forum.isEnabled;
}

final mockForumTopics = <ForumTopic>[
  const ForumTopic(
    id: 'circulo-cuaresma',
    forumId: 'foro-cofradiero',
    title: 'Cuaresma',
    excerpt:
        'Ensayos del día en directo y conversación cofrade de Cuaresma.',
    body:
        'Espacio de Cuaresma para seguir los ensayos del día en directo: dónde va cada uno, avisos de la comunidad y ubicación en mapa.\n\nAbre temas para noticias, dudas y conversación cofrade de la Cuaresma.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.filter_vintage_outlined,
    isPinned: true,
    pinSortOrder: 1,
    isSystem: true,
    seasonKey: 'cuaresma',
    iconKey: 'filter_vintage_outlined',
  ),
  const ForumTopic(
    id: 'circulo-semana-santa',
    forumId: 'foro-cofradiero',
    title: 'Semana Santa',
    excerpt:
        'Avisos en directo de la Semana Mayor: retrasos, recorridos e incidencias.',
    body:
        'Espacio de Semana Santa para seguir la calle en directo con avisos cortos: retrasos, recorrido de hermandades, incidencias y notas de la comunidad.\n\nAbre temas para horarios, itinerarios y tertulia cofrade de la Semana Mayor.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.account_balance,
    isPinned: true,
    pinSortOrder: 2,
    isSystem: true,
    seasonKey: 'semana_santa',
    iconKey: 'account_balance',
  ),
  const ForumTopic(
    id: 'circulo-glorias',
    forumId: 'foro-cofradiero',
    title: 'Glorias',
    excerpt:
        'Festividades y vida cofrade: glorias, romerías, cultos y agenda.',
    body:
        'Espacio de Glorias: festividades, romerías, cultos y la actualidad cofrade de verano y otoño.\n\nConsulta la agenda y abre tertulia con la comunidad.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.wb_sunny_outlined,
    isPinned: true,
    pinSortOrder: 3,
    isSystem: true,
    seasonKey: 'glorias',
    iconKey: 'wb_sunny_outlined',
  ),
  const ForumTopic(
    id: 'martillo-cambio-capataces',
    forumId: 'martillo-trabajadera',
    title: 'Cambio de capataces',
    excerpt:
        'Rumores, confirmaciones y actualidad de traslados de capataces.',
    body:
        'Espacio permanente para la actualidad del costal: cambios de capataces, traslados, nombres que suenan y confirmaciones oficiales.\n\nComparte rumores con respeto y contrasta siempre con fuentes fiables.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.workspace_premium_outlined,
    isPinned: true,
    pinSortOrder: 1,
    isSystem: true,
    iconKey: 'workspace_premium_outlined',
  ),
  const ForumTopic(
    id: 'nueva-ruta-viernes-santo',
    forumId: 'foro-cofradiero',
    title: 'Nueva ruta de la procesión del Viernes Santo',
    excerpt:
        'Os comunicamos que este año la procesión pasará por Plaza Mayor a las 18:30. ¿Qué os parece el nuevo itinerario?',
    body:
        'Queridos cofrades, os comunicamos que este año la procesión del Viernes Santo seguirá un nuevo itinerario que pasará por Plaza Mayor a las 18:30, antes de continuar hacia la Catedral.\n\nEl recorrido ha sido acordado con el Consejo de Hermandades y busca facilitar el acceso de los fieles sin perder la tradición del paso por los puntos más emblemáticos del centro.\n\n¿Qué os parece el cambio? Dejad vuestras opiniones y dudas.',
    authorHandle: '@cofrade_senior',
    timeAgo: 'hace 2 horas',
    commentCount: 2,
    viewCount: 0,
    isResolved: true,
    avatarIcon: Icons.face_3,
  ),
  const ForumTopic(
    id: 'horarios-iguala-costaleros',
    forumId: 'foro-cofradiero',
    title: 'Horarios de la iguala de costaleros',
    excerpt:
        '¿Alguien sabe a qué hora empieza la iguala este sábado en la casa de hermandad?',
    body:
        'Buenas tardes. ¿Alguien sabe a qué hora empieza la iguala de costaleros este sábado en la casa de hermandad? Gracias de antemano.',
    authorHandle: '@jose_carpintero',
    timeAgo: 'hace 4 horas',
    commentCount: 34,
    viewCount: 420,
    avatarIcon: Icons.church,
  ),
  const ForumTopic(
    id: 'banda-procesion-misericordia',
    forumId: 'foro-cofradiero',
    title: 'Banda de la procesión de la Misericordia',
    excerpt:
        'Confirmado el repertorio: Marcha Negra y Amarguras. Ensayo general el jueves.',
    body:
        'Confirmado el repertorio para la procesión: Marcha Negra y Amarguras. Ensayo general el jueves a las 21:00 en el patio de la sede.',
    authorHandle: '@maria_dolores',
    timeAgo: 'hace 6 horas',
    commentCount: 56,
    viewCount: 890,
    avatarIcon: Icons.music_note,
  ),
  const ForumTopic(
    id: 'tunica-nuevo-modelo',
    forumId: 'foro-cofradiero',
    title: 'Nuevo modelo de túnica para nazarenos',
    excerpt:
        'La hermandad presenta el diseño preliminar. Votación abierta hasta el domingo.',
    body:
        'La hermandad presenta el diseño preliminar de la nueva túnica para nazarenos. Votación abierta hasta el domingo en la sede y en este hilo.',
    authorHandle: '@hermandad_sevilla',
    authorVerified: true,
    timeAgo: 'hace 1 día',
    commentCount: 92,
    viewCount: 2100,
    avatarIcon: Icons.workspace_premium_outlined,
  ),
  const ForumTopic(
    id: 'itinerario-extraordinario',
    forumId: 'foro-cofradiero',
    title: 'Itinerario extraordinario por obras en el centro',
    excerpt: 'Desvío temporal por calle Sierpes. Mapa adjunto en el hilo.',
    body:
        'Por las obras en el centro histórico habrá un desvío temporal por calle Sierpes. Adjuntamos mapa con el recorrido alternativo acordado.',
    authorHandle: '@cofrade_senior',
    timeAgo: 'hace 2 días',
    commentCount: 41,
    viewCount: 760,
    avatarIcon: Icons.map_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-la-borriquita',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · La Borriquita',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Borriquita.',
    body:
        'Este es el espacio de seguimiento de La Borriquita para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-la-cena',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · La Cena',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Cena.',
    body:
        'Este es el espacio de seguimiento de La Cena para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-jesus-despojado',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · Jesús Despojado',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de Jesús Despojado.',
    body:
        'Este es el espacio de seguimiento de Jesús Despojado para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-la-hiniesta',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · La Hiniesta',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Hiniesta.',
    body:
        'Este es el espacio de seguimiento de La Hiniesta para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-la-paz',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · La Paz',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Paz.',
    body:
        'Este es el espacio de seguimiento de La Paz para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-san-roque',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · San Roque',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de San Roque.',
    body:
        'Este es el espacio de seguimiento de San Roque para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-la-estrella',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · La Estrella',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Estrella.',
    body:
        'Este es el espacio de seguimiento de La Estrella para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-la-amargura',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · La Amargura',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Amargura.',
    body:
        'Este es el espacio de seguimiento de La Amargura para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'domingo-ramos-el-amor',
    forumId: 'hermandades',
    title: 'Domingo de Ramos · El Amor',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de El Amor.',
    body:
        'Este es el espacio de seguimiento de El Amor para el Domingo de Ramos.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-san-pablo',
    forumId: 'hermandades',
    title: 'Lunes Santo · San Pablo',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de San Pablo.',
    body:
        'Este es el espacio de seguimiento de San Pablo para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 1,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-la-redencion',
    forumId: 'hermandades',
    title: 'Lunes Santo · La Redención',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de La Redención.',
    body:
        'Este es el espacio de seguimiento de La Redención para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-santa-genoveva',
    forumId: 'hermandades',
    title: 'Lunes Santo · Santa Genoveva',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de Santa Genoveva.',
    body:
        'Este es el espacio de seguimiento de Santa Genoveva para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-santa-marta',
    forumId: 'hermandades',
    title: 'Lunes Santo · Santa Marta',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de Santa Marta.',
    body:
        'Este es el espacio de seguimiento de Santa Marta para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-san-gonzalo',
    forumId: 'hermandades',
    title: 'Lunes Santo · San Gonzalo',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de San Gonzalo.',
    body:
        'Este es el espacio de seguimiento de San Gonzalo para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-vera-cruz',
    forumId: 'hermandades',
    title: 'Lunes Santo · Vera Cruz',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de Vera Cruz.',
    body:
        'Este es el espacio de seguimiento de Vera Cruz para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-las-penas',
    forumId: 'hermandades',
    title: 'Lunes Santo · Las Penas',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de Las Penas.',
    body:
        'Este es el espacio de seguimiento de Las Penas para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-las-aguas',
    forumId: 'hermandades',
    title: 'Lunes Santo · Las Aguas',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de Las Aguas.',
    body:
        'Este es el espacio de seguimiento de Las Aguas para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumTopic(
    id: 'lunes-santo-el-museo',
    forumId: 'hermandades',
    title: 'Lunes Santo · El Museo',
    excerpt:
        'Espacio para noticias, horarios, avisos e información oficial de El Museo.',
    body:
        'Este es el espacio de seguimiento de El Museo para el Lunes Santo.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
    authorHandle: '@cofradeo',
    authorVerified: true,
    timeAgo: 'sin actividad',
    commentCount: 0,
    viewCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  ..._additionalHermandadTopics,
];

final _additionalHermandadTopics = _hermandadData
    .map(
      (item) => ForumTopic(
        id: '${item.daySlug}-${item.hermandadSlug}',
        forumId: 'hermandades',
        title: '${item.dayLabel} · ${item.hermandadName}',
        excerpt:
            'Espacio para noticias, horarios, avisos e información oficial de ${item.hermandadName}.',
        body:
            'Este es el espacio de seguimiento de ${item.hermandadName} para ${item.dayLabel}.\n\nAquí se podrán centralizar noticias, horarios, avisos de última hora, comunicados, cambios de itinerario y comentarios de la comunidad.\n\nCuando exista una cuenta verificada de la hermandad, sus publicaciones aparecerán identificadas como información oficial.',
        authorHandle: '@cofradeo',
        authorVerified: true,
        timeAgo: 'sin actividad',
        commentCount: 0,
        viewCount: 0,
        avatarIcon: Icons.groups_outlined,
      ),
    )
    .toList(growable: false);

const _hermandadData = <_HermandadTopicSeed>[
  _HermandadTopicSeed(
    'Viernes de Dolores',
    'viernes-dolores',
    'Bendición y Esperanza',
    'bendicion-esperanza',
  ),
  _HermandadTopicSeed(
    'Viernes de Dolores',
    'viernes-dolores',
    'Pino Montano',
    'pino-montano',
  ),
  _HermandadTopicSeed(
    'Viernes de Dolores',
    'viernes-dolores',
    'La Misión',
    'la-mision',
  ),
  _HermandadTopicSeed(
    'Viernes de Dolores',
    'viernes-dolores',
    'Bellavista',
    'bellavista',
  ),
  _HermandadTopicSeed(
    'Viernes de Dolores',
    'viernes-dolores',
    'La Corona',
    'la-corona',
  ),
  _HermandadTopicSeed(
    'Viernes de Dolores',
    'viernes-dolores',
    'Pasión y Muerte',
    'pasion-y-muerte',
  ),
  _HermandadTopicSeed(
    'Sábado de Pasión',
    'sabado-pasion',
    'Padre Pío',
    'padre-pio',
  ),
  _HermandadTopicSeed(
    'Sábado de Pasión',
    'sabado-pasion',
    'La Milagrosa',
    'la-milagrosa',
  ),
  _HermandadTopicSeed(
    'Sábado de Pasión',
    'sabado-pasion',
    'Torreblanca',
    'torreblanca',
  ),
  _HermandadTopicSeed(
    'Sábado de Pasión',
    'sabado-pasion',
    'San José Obrero',
    'san-jose-obrero',
  ),
  _HermandadTopicSeed(
    'Sábado de Pasión',
    'sabado-pasion',
    'Divino Perdón',
    'divino-perdon',
  ),
  _HermandadTopicSeed('Martes Santo', 'martes-santo', 'El Cerro', 'el-cerro'),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'San Esteban',
    'san-esteban',
  ),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'La Candelaria',
    'la-candelaria',
  ),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'San Benito',
    'san-benito',
  ),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'Los Javieres',
    'los-javieres',
  ),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'El Dulce Nombre',
    'el-dulce-nombre',
  ),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'Los Estudiantes',
    'los-estudiantes',
  ),
  _HermandadTopicSeed(
    'Martes Santo',
    'martes-santo',
    'Santa Cruz',
    'santa-cruz',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'El Carmen Doloroso',
    'el-carmen-doloroso',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'El Buen Fin',
    'el-buen-fin',
  ),
  _HermandadTopicSeed('Miércoles Santo', 'miercoles-santo', 'La Sed', 'la-sed'),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'San Bernardo',
    'san-bernardo',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'La Lanzada',
    'la-lanzada',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'El Baratillo',
    'el-baratillo',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'Los Panaderos',
    'los-panaderos',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'Cristo de Burgos',
    'cristo-de-burgos',
  ),
  _HermandadTopicSeed(
    'Miércoles Santo',
    'miercoles-santo',
    'Las Siete Palabras',
    'las-siete-palabras',
  ),
  _HermandadTopicSeed(
    'Jueves Santo',
    'jueves-santo',
    'Los Negritos',
    'los-negritos',
  ),
  _HermandadTopicSeed(
    'Jueves Santo',
    'jueves-santo',
    'La Exaltación',
    'la-exaltacion',
  ),
  _HermandadTopicSeed(
    'Jueves Santo',
    'jueves-santo',
    'Las Cigarreras',
    'las-cigarreras',
  ),
  _HermandadTopicSeed('Jueves Santo', 'jueves-santo', 'Montesión', 'montesion'),
  _HermandadTopicSeed(
    'Jueves Santo',
    'jueves-santo',
    'La Quinta Angustia',
    'la-quinta-angustia',
  ),
  _HermandadTopicSeed('Jueves Santo', 'jueves-santo', 'El Valle', 'el-valle'),
  _HermandadTopicSeed('Jueves Santo', 'jueves-santo', 'Pasión', 'pasion'),
  _HermandadTopicSeed('Madrugá', 'madruga', 'El Silencio', 'el-silencio'),
  _HermandadTopicSeed('Madrugá', 'madruga', 'El Gran Poder', 'el-gran-poder'),
  _HermandadTopicSeed('Madrugá', 'madruga', 'La Macarena', 'la-macarena'),
  _HermandadTopicSeed('Madrugá', 'madruga', 'El Calvario', 'el-calvario'),
  _HermandadTopicSeed(
    'Madrugá',
    'madruga',
    'La Esperanza de Triana',
    'la-esperanza-de-triana',
  ),
  _HermandadTopicSeed('Madrugá', 'madruga', 'Los Gitanos', 'los-gitanos'),
  _HermandadTopicSeed(
    'Viernes Santo',
    'viernes-santo',
    'La Carretería',
    'la-carreteria',
  ),
  _HermandadTopicSeed(
    'Viernes Santo',
    'viernes-santo',
    'Soledad de San Buenaventura',
    'soledad-san-buenaventura',
  ),
  _HermandadTopicSeed(
    'Viernes Santo',
    'viernes-santo',
    'El Cachorro',
    'el-cachorro',
  ),
  _HermandadTopicSeed('Viernes Santo', 'viernes-santo', 'La O', 'la-o'),
  _HermandadTopicSeed(
    'Viernes Santo',
    'viernes-santo',
    'San Isidoro',
    'san-isidoro',
  ),
  _HermandadTopicSeed(
    'Viernes Santo',
    'viernes-santo',
    'Montserrat',
    'montserrat',
  ),
  _HermandadTopicSeed(
    'Viernes Santo',
    'viernes-santo',
    'La Mortaja',
    'la-mortaja',
  ),
  _HermandadTopicSeed('Sábado Santo', 'sabado-santo', 'El Sol', 'el-sol'),
  _HermandadTopicSeed(
    'Sábado Santo',
    'sabado-santo',
    'Los Servitas',
    'los-servitas',
  ),
  _HermandadTopicSeed(
    'Sábado Santo',
    'sabado-santo',
    'La Trinidad',
    'la-trinidad',
  ),
  _HermandadTopicSeed(
    'Sábado Santo',
    'sabado-santo',
    'El Santo Entierro',
    'el-santo-entierro',
  ),
  _HermandadTopicSeed(
    'Sábado Santo',
    'sabado-santo',
    'La Soledad de San Lorenzo',
    'la-soledad-de-san-lorenzo',
  ),
  _HermandadTopicSeed(
    'Domingo de Resurrección',
    'domingo-resurreccion',
    'La Resurrección',
    'la-resurreccion',
  ),
];

class _HermandadTopicSeed {
  const _HermandadTopicSeed(
    this.dayLabel,
    this.daySlug,
    this.hermandadName,
    this.hermandadSlug,
  );

  final String dayLabel;
  final String daySlug;
  final String hermandadName;
  final String hermandadSlug;
}

final mockForumReplies = <ForumReply>[
  const ForumReply(
    id: 'official-san-pablo-1',
    topicId: 'lunes-santo-san-pablo',
    authorHandle: '@hdad_sanpablo',
    authorVerified: true,
    isOfficial: true,
    officialCategory: 'noticia',
    timeAgo: 'hace 10 min',
    content:
        'Aviso oficial: este espacio recogerá las noticias, cultos y comunicados de la hermandad cuando la cuenta verificada esté activa.',
    commentCount: 0,
    likeCount: 0,
    avatarIcon: Icons.groups_outlined,
  ),
  const ForumReply(
    id: 'reply-2',
    topicId: 'nueva-ruta-viernes-santo',
    authorHandle: '@maria_dolores',
    timeAgo: 'hace 45 min',
    content:
        'Muchas gracias por la información, @cofrade_senior. El nuevo itinerario me parece muy acertado para agilizar el paso.',
    commentCount: 8,
    likeCount: 31,
    avatarIcon: Icons.wine_bar_outlined,
  ),
  const ForumReply(
    id: 'reply-1',
    topicId: 'nueva-ruta-viernes-santo',
    authorHandle: '@jose_carpintero',
    timeAgo: 'hace 1 hora',
    content:
        '¿Sabe alguien qué banda acompañará a la procesión este año? En el tramo de Plaza Mayor me gustaría escuchar las marchas.',
    commentCount: 15,
    likeCount: 24,
    avatarIcon: Icons.church,
  ),
];

ForumTopic? topicById(String forumId, String topicId) {
  try {
    return mockForumTopics.firstWhere(
      (t) => t.id == topicId && t.forumId == forumId,
    );
  } catch (_) {
    return null;
  }
}

List<ForumReply> repliesForTopic(String topicId) {
  return mockForumReplies.where((r) => r.topicId == topicId).toList();
}

String formatForumStatsLine(ForumCategory forum) {
  return '${formatCount(forum.topicCount)} temas · ${formatCount(forum.messageCount)} respuestas';
}

String formatForumActivityLine(ForumCategory forum) {
  if (!forum.isEnabled) return '';
  if (forum.lastMessageAgo == 'sin actividad') {
    return 'Sin actividad reciente';
  }
  return 'Activo ${forum.lastMessageAgo}';
}

String truncateForumTopicTitle(String title, {int max = 44}) {
  if (title.length <= max) return title;
  return '${title.substring(0, max - 1)}…';
}

String formatForumLastTopicLine(ForumCategory forum) {
  if (!forum.isEnabled) return '';
  final title = forum.lastTopicTitle?.trim();
  if (title != null && title.isNotEmpty) {
    final ago = forum.lastMessageAgo == 'sin actividad'
        ? ''
        : ' · ${forum.lastMessageAgo}';
    return 'Último: ${truncateForumTopicTitle(title)}$ago';
  }
  return formatForumActivityLine(forum);
}

List<ForumTopic> topicsForForum(String forumId) {
  if (!canAccessForum(forumId)) return [];
  final topics =
        mockForumTopics.where((t) => t.forumId == forumId).toList();
  return orderForumTopics(topics);
}

String formatCount(int n) {
  if (n >= 10000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
  }
  return _countFormat.format(n);
}
