import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/app_notification.dart';

final mockNotifications = <AppNotification>[
  const AppNotification(
    id: 'notif-1',
    title: 'Nuevo comentario en #ViernesSanto',
    subtitle:
        'Nueva ruta de la procesión del Viernes Santo · @jose_carpintero',
    timeAgo: 'Hace 5 min',
    kind: AppNotificationKind.hashtagActivity,
    avatarIcon: Icons.face_3,
    forumId: 'foro-cofradiero',
    topicId: 'nueva-ruta-viernes-santo',
  ),
  const AppNotification(
    id: 'notif-2',
    title: 'Hermandad Sevilla publicó',
    subtitle: 'Confirmado el repertorio: Marcha Negra y Amarguras.',
    timeAgo: 'Hace 1 hora',
    kind: AppNotificationKind.userPost,
    avatarIcon: Icons.church,
    forumId: 'foro-cofradiero',
    topicId: 'banda-procesion-misericordia',
  ),
  const AppNotification(
    id: 'notif-3',
    title: 'Te han etiquetado en un post',
    subtitle: '@maria_dolores te mencionó en #MarchasCofradas',
    timeAgo: 'Ayer',
    kind: AppNotificationKind.mention,
    badgeIcon: Icons.favorite,
    badgeBackgroundColor: AppColors.accentRed,
    forumId: 'foro-cofradiero',
    topicId: 'banda-procesion-misericordia',
  ),
  const AppNotification(
    id: 'notif-4',
    title: 'Evento mañana',
    subtitle: 'Salida de procesión · Ntra. Sra. de la Misericordia · 18:00',
    timeAgo: 'Ayer',
    kind: AppNotificationKind.calendarEvent,
    badgeIcon: Icons.wine_bar_outlined,
    badgeBackgroundColor: AppColors.burgundy,
    route: '/calendario',
  ),
  const AppNotification(
    id: 'notif-5',
    title: 'Nuevo seguidor',
    subtitle: '@jose_carpintero empezó a seguirte',
    timeAgo: 'Hace 2 días',
    kind: AppNotificationKind.newFollower,
    isRead: true,
    badgeIcon: Icons.person_add_outlined,
    badgeBackgroundColor: AppColors.burgundy,
    route: '/perfil',
  ),
];
