class FollowedTopic {
  const FollowedTopic({
    required this.topicId,
    required this.forumId,
    required this.title,
    required this.preview,
    this.notifyOfficialCategories,
  });

  final String topicId;
  final String forumId;
  final String title;
  final String preview;

  /// Tablones hermandad: `null` = todas las secciones; `[]` = ninguna.
  final List<String>? notifyOfficialCategories;

  bool get isHermandadBoard => forumId == 'hermandades';
}
