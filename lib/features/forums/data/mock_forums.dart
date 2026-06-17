import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/forum.dart';

final _countFormat = NumberFormat('#,###', 'es');

final mockForumCategories = <ForumCategory>[
  const ForumCategory(
    id: 'foro-cofradiero',
    name: 'Foro Cofradiero',
    description: 'El lugar de encuentro para todos los cofrades.',
    icon: Icons.church,
    sortOrder: 1,
    topicCount: 5,
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
    description: 'La música que acompaña nuestra Semana Santa.',
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
    description: 'El arte de la talla, el bordado y la orfebrería.',
    icon: Icons.workspace_premium_outlined,
    sortOrder: 3,
    topicCount: 0,
    messageCount: 0,
    lastMessageAgo: 'sin actividad',
    isEnabled: true,
    isActive: false,
  ),
  const ForumCategory(
    id: 'semana-santa',
    name: 'Semana Santa',
    description: 'Todo sobre la Semana Mayor: procesiones, horarios y noticias.',
    icon: Icons.account_balance,
    sortOrder: 4,
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
    sortOrder: 5,
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
    description: 'Procesiones de gloria, Domingo de Resurrección y cultos de gloria.',
    icon: Icons.wb_sunny_outlined,
    sortOrder: 6,
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
  return [...mockForumCategories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
];

final mockForumReplies = <ForumReply>[
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
  return mockForumTopics.where((t) => t.forumId == forumId).toList();
}

String formatCount(int n) {
  if (n >= 10000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
  }
  return _countFormat.format(n);
}
