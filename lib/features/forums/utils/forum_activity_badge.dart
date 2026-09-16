import '../../../shared/models/forum.dart';

enum ForumActivityLevel { veryActive, active, low, upcoming }

ForumActivityLevel forumActivityLevel(ForumCategory forum) {
  if (forum.isLocked) return ForumActivityLevel.upcoming;

  final engagement = forum.messageCount + forum.topicCount;

  if (forum.messageCount >= 100 ||
      (forum.isActive && forum.messageCount >= 15)) {
    return ForumActivityLevel.veryActive;
  }
  if (forum.isActive || engagement >= 3) {
    return ForumActivityLevel.active;
  }
  return ForumActivityLevel.low;
}

String forumActivityLabel(ForumActivityLevel level) {
  return switch (level) {
    ForumActivityLevel.veryActive => 'Muy activo',
    ForumActivityLevel.active => 'Activo',
    ForumActivityLevel.low => 'Actividad baja',
    ForumActivityLevel.upcoming => 'Próx.',
  };
}
