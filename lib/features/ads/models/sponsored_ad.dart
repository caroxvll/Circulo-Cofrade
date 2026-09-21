enum AdPlacement {
  home('home'),
  forumsTop('forums_top'),
  forumsMiddle('forums_middle'),
  forumsEvent('forums_event'),
  featuredTopic('featured_topic'),
  calendar('calendar'),
  search('search'),
  profile('profile'),
  hermandades('hermandades'),
  noticias('noticias');

  const AdPlacement(this.value);

  final String value;
}

class SponsoredAd {
  const SponsoredAd({
    required this.id,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.buttonText,
    required this.targetUrl,
    required this.placement,
    this.imageUrl,
    this.sponsorLogoUrl,
    this.calendarEventId,
    this.forumId,
    this.topicId,
    this.priority = 1,
    this.maxImpressions = 5000,
    this.currentImpressions = 0,
    this.active = true,
  });

  final String id;
  final String title;
  final String description;
  final String sponsorName;
  final String buttonText;
  final String targetUrl;
  final AdPlacement placement;
  final String? imageUrl;
  final String? sponsorLogoUrl;
  final String? calendarEventId;
  final String? forumId;
  final String? topicId;
  final int priority;
  final int maxImpressions;
  final int currentImpressions;
  final bool active;

  factory SponsoredAd.fromRow(Map<String, dynamic> row) {
    return SponsoredAd(
      id: row['id'].toString(),
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      sponsorName: row['sponsor_name'] as String? ?? '',
      buttonText: row['button_text'] as String? ?? 'Ver más',
      targetUrl: row['target_url'] as String? ?? '',
      placement: _placementFromString(row['placement'] as String?),
      imageUrl: row['image_url'] as String?,
      sponsorLogoUrl: row['sponsor_logo_url'] as String?,
      calendarEventId: row['calendar_event_id'] as String?,
      forumId: row['forum_id'] as String?,
      topicId: row['topic_id'] as String?,
      priority: row['priority'] as int? ?? 1,
      maxImpressions: row['max_impressions'] as int? ?? 5000,
      currentImpressions: row['current_impressions'] as int? ?? 0,
      active: row['active'] as bool? ?? true,
    );
  }

  static AdPlacement _placementFromString(String? value) {
    return AdPlacement.values.firstWhere(
      (placement) => placement.value == value,
      orElse: () => AdPlacement.forumsTop,
    );
  }
}
