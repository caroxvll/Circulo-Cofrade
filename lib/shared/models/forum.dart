import 'package:flutter/material.dart';

enum TopicStatus { pending, published, rejected }

enum TopicCloseStatus { open, closeRequested, closed }

extension TopicCloseStatusX on TopicCloseStatus {
  static TopicCloseStatus fromDb(String? raw) => switch (raw) {
    'close_requested' => TopicCloseStatus.closeRequested,
    'closed' => TopicCloseStatus.closed,
    _ => TopicCloseStatus.open,
  };

  String get dbValue => switch (this) {
    TopicCloseStatus.open => 'open',
    TopicCloseStatus.closeRequested => 'close_requested',
    TopicCloseStatus.closed => 'closed',
  };
}

/// Pilar del foro (categoría raíz fija).
class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.sortOrder,
    required this.topicCount,
    required this.messageCount,
    required this.lastMessageAgo,
    this.lastTopicId,
    this.lastTopicTitle,
    this.isEnabled = true,
    this.isActive = false,
    this.lockedLabel,
    this.headerIcon = Icons.church,
    this.iconKey,
    this.iconImageUrl,
    this.coverImageUrl,
    this.aboutTagline,
    this.aboutBody,
    this.forumRules,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;

  /// Menor número = más arriba en la lista.
  final int sortOrder;
  final int topicCount;
  final int messageCount;

  /// Texto relativo de la última actividad (tema o respuesta).
  final String lastMessageAgo;

  /// Hilo con actividad más reciente en este foro.
  final String? lastTopicId;
  final String? lastTopicTitle;

  /// Si false, el pilar está oculto en FOROS (solo visible en Junta).
  final bool isEnabled;

  /// Badge «Activo» cuando la comunidad está muy viva.
  final bool isActive;

  /// Mensaje cuando está bloqueado, ej. «Se activará en Cuaresma».
  final String? lockedLabel;
  final IconData headerIcon;

  /// Clave Material (`icon_key` en Supabase) si no hay imagen.
  final String? iconKey;

  /// URL o asset remoto del icono del foro (prioridad sobre el asset empaquetado).
  final String? iconImageUrl;

  /// Portada del foro (tarjeta en la lista y hero del detalle).
  final String? coverImageUrl;

  /// Frase corta bajo el nombre en «Acerca del foro».
  final String? aboutTagline;

  /// Texto largo de presentación (si vacío, usa [description]).
  final String? aboutBody;

  /// Normas del foro, una por línea.
  final String? forumRules;

  final DateTime? createdAt;

  /// Apartado de publicaciones oficiales (no foro de debate).
  bool get isHermandadesChannel => id == 'hermandades';

  String get aboutTaglineDisplay {
    final t = aboutTagline?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (isHermandadesChannel) {
      return 'Noticias, cultos, actos y patrimonio de las hermandades de Sevilla.';
    }
    final d = description.trim();
    if (d.isNotEmpty) return d;
    return 'El lugar de encuentro para todos los cofrades.';
  }

  String get aboutBodyDisplay {
    final b = aboutBody?.trim();
    if (b != null && b.isNotEmpty) return b;
    if (isHermandadesChannel) {
      return 'Este apartado no es un foro de debate. Aquí cada hermandad '
          'publica de forma oficial sus noticias, cultos, actos y patrimonio '
          'a través de su cuenta verificada.\n\n'
          'Los cofrades pueden consultar y seguir la actualidad, pero no es '
          'posible abrir temas ni comentar: el contenido lo gestionan '
          'exclusivamente las cuentas verificadas de cada hermandad.';
    }
    return description.trim();
  }

  List<String> get forumRulesList {
    final raw = forumRules?.trim();
    if (raw == null || raw.isEmpty) {
      return isHermandadesChannel
          ? defaultHermandadesRules
          : defaultForumRules;
    }
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static const defaultForumRules = [
    'Respeta a todos los miembros.',
    'No difundir mensajes ofensivos.',
    'No enviar spam ni publicidad.',
    'Mantén los temas dentro del ámbito del foro.',
    'Protege la privacidad de otros usuarios.',
  ];

  static const defaultHermandadesRules = [
    'Solo las hermandades con cuenta verificada pueden publicar.',
    'No está permitido abrir temas ni comentar en este apartado.',
    'El contenido es informativo: noticias, cultos, actos y patrimonio.',
    'Cada publicación es responsabilidad de la hermandad que la emite.',
    'Para dudas concretas, contacta con la hermandad por sus canales oficiales.',
  ];

  bool get isLocked => !isEnabled;
}

class ForumTopic {
  const ForumTopic({
    required this.id,
    required this.forumId,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.authorHandle,
    required this.timeAgo,
    required this.commentCount,
    required this.viewCount,
    this.isResolved = false,
    this.avatarIcon = Icons.face_3,
    this.authorId,
    this.authorAvatarUrl,
    this.authorVerified = false,
    this.authorTrophyPoints = 0,
    this.status = TopicStatus.published,
    this.isPinned = false,
    this.pinSortOrder = 0,
    this.isSystem = false,
    this.seasonKey,
    this.iconKey,
    this.coverImageUrl,
    this.showHubTitle = true,
    this.isListed = true,
    this.createdAt,
    this.closeStatus = TopicCloseStatus.open,
    this.isClosed = false,
    this.editedAt,
    this.rejectionReason,
    this.rejectedAt,
    this.relatedForumId,
  });

  final String id;
  final String forumId;
  final String title;
  final String excerpt;
  final String body;
  final String authorHandle;
  final String timeAgo;
  final int commentCount;
  final int viewCount;
  final bool isResolved;
  final IconData avatarIcon;
  final String? authorId;
  final String? authorAvatarUrl;
  final bool authorVerified;
  final int authorTrophyPoints;
  final TopicStatus status;
  final bool isPinned;
  final int pinSortOrder;
  final bool isSystem;

  /// `cuaresma`, `semana_santa` o `glorias` para reorden estacional.
  final String? seasonKey;
  final String? iconKey;
  final String? coverImageUrl;

  /// En hubs estacionales: mostrar icono + título sobre la portada.
  final bool showHubTitle;
  final bool isListed;
  final DateTime? createdAt;
  final TopicCloseStatus closeStatus;
  final bool isClosed;
  final DateTime? editedAt;
  final String? rejectionReason;
  final DateTime? rejectedAt;

  /// Foro etiquetado en noticias (p. ej. `pentagrama-cofrade`). No duplica el tema.
  final String? relatedForumId;

  bool get isPublished => status == TopicStatus.published;
  bool get isPending => status == TopicStatus.pending;
  bool get isRejected => status == TopicStatus.rejected;
  bool get isCloseRequested => closeStatus == TopicCloseStatus.closeRequested;
  bool get acceptsReplies => isPublished && !isClosed;

  int get sortTimestamp => createdAt?.millisecondsSinceEpoch ?? 0;
}

class ForumReply {
  const ForumReply({
    required this.id,
    required this.topicId,
    required this.authorHandle,
    required this.timeAgo,
    required this.content,
    required this.commentCount,
    required this.likeCount,
    this.avatarIcon = Icons.church,
    this.authorId,
    this.authorAvatarUrl,
    this.authorVerified = false,
    this.authorTrophyPoints = 0,
    this.isOfficial = false,
    this.officialCategory,
    this.parentReplyId,
    this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.isFeatured = false,
    this.imageUrl,
  });

  final String id;
  final String topicId;
  final String authorHandle;
  final String timeAgo;
  final String content;
  final int commentCount;
  final int likeCount;
  final IconData avatarIcon;
  final String? authorId;
  final String? authorAvatarUrl;
  final bool authorVerified;
  final int authorTrophyPoints;
  final bool isOfficial;
  final String? officialCategory;
  final String? parentReplyId;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final bool isFeatured;
  final String? imageUrl;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;

  /// Texto visible en el hilo (el contenido real se conserva en BD).
  String get displayContent =>
      isDeleted ? 'Comentario eliminado por el autor.' : content;

  ForumReply copyWith({
    String? id,
    String? topicId,
    String? authorHandle,
    String? timeAgo,
    String? content,
    int? commentCount,
    int? likeCount,
    IconData? avatarIcon,
    String? authorId,
    String? authorAvatarUrl,
    bool? authorVerified,
    int? authorTrophyPoints,
    bool? isOfficial,
    String? officialCategory,
    String? parentReplyId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    bool? isFeatured,
    String? imageUrl,
  }) {
    return ForumReply(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      authorHandle: authorHandle ?? this.authorHandle,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      authorId: authorId ?? this.authorId,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorVerified: authorVerified ?? this.authorVerified,
      authorTrophyPoints: authorTrophyPoints ?? this.authorTrophyPoints,
      isOfficial: isOfficial ?? this.isOfficial,
      officialCategory: officialCategory ?? this.officialCategory,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isFeatured: isFeatured ?? this.isFeatured,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
