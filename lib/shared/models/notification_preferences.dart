class NotificationPreferences {
  const NotificationPreferences({
    this.notifyHashtags = true,
    this.notifyProfiles = true,
    this.notifyTopics = true,
    this.notifyMentions = true,
    this.notifyFollowers = false,
    this.pushEnabled = false,
  });

  final bool notifyHashtags;
  final bool notifyProfiles;
  final bool notifyTopics;
  final bool notifyMentions;
  final bool notifyFollowers;
  final bool pushEnabled;

  NotificationPreferences copyWith({
    bool? notifyHashtags,
    bool? notifyProfiles,
    bool? notifyTopics,
    bool? notifyMentions,
    bool? notifyFollowers,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      notifyHashtags: notifyHashtags ?? this.notifyHashtags,
      notifyProfiles: notifyProfiles ?? this.notifyProfiles,
      notifyTopics: notifyTopics ?? this.notifyTopics,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      notifyFollowers: notifyFollowers ?? this.notifyFollowers,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
