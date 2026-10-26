class TopicPollOption {
  const TopicPollOption({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.voteCount,
  });

  final String id;
  final String label;
  final int sortOrder;
  final int voteCount;
}

class TopicPoll {
  const TopicPoll({
    required this.id,
    required this.topicId,
    required this.question,
    required this.options,
    this.myOptionId,
    this.closedAt,
  });

  final String id;
  final String topicId;
  final String question;
  final List<TopicPollOption> options;
  final String? myOptionId;
  final DateTime? closedAt;

  int get totalVotes =>
      options.fold<int>(0, (sum, o) => sum + o.voteCount);

  bool get isClosed => closedAt != null;

  bool get hasVoted => myOptionId != null;
}

/// Borrador local al crear el tema (aún sin IDs de servidor).
class TopicPollDraft {
  const TopicPollDraft({
    required this.question,
    required this.options,
  });

  final String question;
  final List<String> options;
}
