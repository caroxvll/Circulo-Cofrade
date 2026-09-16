class NotificationPreferences {
  const NotificationPreferences({
    this.notifyHashtags = true,
    this.notifyProfiles = true,
    this.notifyTopics = true,
    this.notifyMentions = true,
    this.notifyFollowers = false,
    this.notifyReactions = true,
    this.notifyCalendar = false,
    this.notifyQuiz = true,
    this.notifyNews = true,
    this.pushEnabled = false,
  });

  final bool notifyHashtags;
  final bool notifyProfiles;
  final bool notifyTopics;
  final bool notifyMentions;
  final bool notifyFollowers;
  final bool notifyReactions;
  final bool notifyCalendar;
  final bool notifyQuiz;
  final bool notifyNews;
  final bool pushEnabled;

  NotificationPreferences copyWith({
    bool? notifyHashtags,
    bool? notifyProfiles,
    bool? notifyTopics,
    bool? notifyMentions,
    bool? notifyFollowers,
    bool? notifyReactions,
    bool? notifyCalendar,
    bool? notifyQuiz,
    bool? notifyNews,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      notifyHashtags: notifyHashtags ?? this.notifyHashtags,
      notifyProfiles: notifyProfiles ?? this.notifyProfiles,
      notifyTopics: notifyTopics ?? this.notifyTopics,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      notifyFollowers: notifyFollowers ?? this.notifyFollowers,
      notifyReactions: notifyReactions ?? this.notifyReactions,
      notifyCalendar: notifyCalendar ?? this.notifyCalendar,
      notifyQuiz: notifyQuiz ?? this.notifyQuiz,
      notifyNews: notifyNews ?? this.notifyNews,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
