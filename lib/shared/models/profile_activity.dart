import 'forum.dart';

enum ProfileActivityType { topic, reply }

class ProfileActivity {
  const ProfileActivity({
    required this.id,
    required this.type,
    required this.forumId,
    required this.forumName,
    required this.topicId,
    required this.title,
    required this.preview,
    required this.timeAgo,
    this.topicStatus,
    this.forumIconKey,
    this.coverImageUrl,
    this.viewCount = 0,
    this.commentCount = 0,
    this.reactionCount = 0,
    this.seasonKey,
  });

  final String id;
  final ProfileActivityType type;
  final String forumId;
  final String forumName;
  final String topicId;
  final String title;
  final String preview;
  final String timeAgo;
  final TopicStatus? topicStatus;
  final String? forumIconKey;
  final String? coverImageUrl;
  final int viewCount;
  final int commentCount;
  final int reactionCount;
  final String? seasonKey;

  /// Clave del filtro: el espacio de temporada, o el foro si no tiene.
  String get placeKey => seasonKey ?? forumId;

  /// Dónde se publicó: foro, o el espacio de temporada si no es un tema del foro.
  String get placeName {
    return switch (seasonKey) {
      'cuaresma' => 'Cuaresma',
      'semana_santa' => 'Semana Santa',
      'glorias' => 'Glorias',
      _ => forumName,
    };
  }

  String get originLabel {
    final kind = isTopic ? 'Tema' : 'Respuesta';
    return '$kind · $placeName';
  }

  String get typeLabel {
    if (type == ProfileActivityType.reply) return 'Respuesta';
    return switch (topicStatus) {
      TopicStatus.pending => 'Pendiente · Junta',
      TopicStatus.rejected => 'No publicado',
      TopicStatus.published || null => 'Publicado',
    };
  }

  bool get isTopic => type == ProfileActivityType.topic;
}
