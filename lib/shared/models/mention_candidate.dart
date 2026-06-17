class MentionCandidate {
  const MentionCandidate({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;

  String get mentionHandle =>
      handle.startsWith('@') ? handle : '@$handle';
}
