class EventLiveUpdate {
  const EventLiveUpdate({
    required this.id,
    required this.calendarEventId,
    required this.userId,
    required this.authorHandle,
    required this.message,
    required this.createdAt,
    this.placeLabel,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String calendarEventId;
  final String userId;
  final String authorHandle;
  final String message;
  final DateTime createdAt;
  final String? placeLabel;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}
