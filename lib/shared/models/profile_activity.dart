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
    this.viewCount = 0,
    this.commentCount = 0,
    this.reactionCount = 0,
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
  final int viewCount;
  final int commentCount;
  final int reactionCount;

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
