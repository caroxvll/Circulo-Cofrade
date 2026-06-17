import 'forum.dart';

enum ProfileActivityType { topic, reply }

class ProfileActivity {
  const ProfileActivity({
    required this.id,
    required this.type,
    required this.forumId,
    required this.topicId,
    required this.title,
    required this.preview,
    required this.timeAgo,
    this.topicStatus,
  });

  final String id;
  final ProfileActivityType type;
  final String forumId;
  final String topicId;
  final String title;
  final String preview;
  final String timeAgo;
  final TopicStatus? topicStatus;

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
