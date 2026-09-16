class HermandadScheduledPost {
  const HermandadScheduledPost({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    required this.content,
    required this.officialCategory,
    required this.status,
    this.scheduledAt,
    this.publishedReplyId,
    this.updatedAt,
    this.imageUrl,
  });

  final String id;
  final String topicId;
  final String topicTitle;
  final String content;
  final String officialCategory;
  final DateTime? scheduledAt;
  final String status;
  final String? publishedReplyId;
  final DateTime? updatedAt;
  final String? imageUrl;

  bool get isDraft => status == 'draft';
  bool get isScheduled => status == 'scheduled';
  bool get isCancelled => status == 'cancelled';
  bool get isPublished => status == 'published';

  factory HermandadScheduledPost.fromRow(Map<String, dynamic> row) {
    final topic = row['forum_topics'];
    final topicTitle = topic is Map<String, dynamic>
        ? topic['title'] as String? ?? ''
        : row['topic_title'] as String? ?? '';

    final scheduledRaw = row['scheduled_at'] as String?;
    final updatedRaw = row['updated_at'] as String?;

    return HermandadScheduledPost(
      id: row['id'] as String,
      topicId: row['topic_id'] as String,
      topicTitle: topicTitle,
      content: row['content'] as String,
      officialCategory: row['official_category'] as String? ?? 'noticia',
      scheduledAt: scheduledRaw != null
          ? DateTime.parse(scheduledRaw).toLocal()
          : null,
      status: row['status'] as String? ?? 'scheduled',
      publishedReplyId: row['published_reply_id'] as String?,
      updatedAt:
          updatedRaw != null ? DateTime.parse(updatedRaw).toLocal() : null,
      imageUrl: row['image_url'] as String?,
    );
  }
}

class HermandadPendingPosts {
  const HermandadPendingPosts({
    required this.drafts,
    required this.scheduled,
  });

  final List<HermandadScheduledPost> drafts;
  final List<HermandadScheduledPost> scheduled;

  bool get isEmpty => drafts.isEmpty && scheduled.isEmpty;
}
