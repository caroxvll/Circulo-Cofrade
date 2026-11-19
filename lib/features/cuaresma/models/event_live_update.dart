class EventLiveUpdate {
  const EventLiveUpdate({
    required this.id,
    required this.calendarEventId,
    required this.userId,
    required this.authorHandle,
    required this.message,
    required this.createdAt,
    this.authorAvatarUrl,
    this.placeLabel,
    this.latitude,
    this.longitude,
    this.featuredAt,
  });

  final String id;
  final String calendarEventId;
  final String userId;
  final String authorHandle;
  final String? authorAvatarUrl;
  final String message;
  final DateTime createdAt;
  final String? placeLabel;
  final double? latitude;
  final double? longitude;

  /// Momento en que el admin o la Junta lo sacó a Para ti.
  final DateTime? featuredAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get shownInParaTi => featuredAt != null;

  EventLiveUpdate copyWith({
    DateTime? featuredAt,
    bool clearFeatured = false,
  }) {
    return EventLiveUpdate(
      id: id,
      calendarEventId: calendarEventId,
      userId: userId,
      authorHandle: authorHandle,
      authorAvatarUrl: authorAvatarUrl,
      message: message,
      createdAt: createdAt,
      placeLabel: placeLabel,
      latitude: latitude,
      longitude: longitude,
      featuredAt: clearFeatured ? null : (featuredAt ?? this.featuredAt),
    );
  }
}
