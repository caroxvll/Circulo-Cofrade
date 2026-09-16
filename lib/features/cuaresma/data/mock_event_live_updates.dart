import 'dart:math';

import '../models/event_live_update.dart';

final _mockLiveUpdates = <EventLiveUpdate>[];

List<EventLiveUpdate> mockEventLiveUpdatesFor(String eventId) {
  return _mockLiveUpdates
      .where((u) => u.calendarEventId == eventId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

EventLiveUpdate addMockEventLiveUpdate({
  required String eventId,
  required String userId,
  required String authorHandle,
  required String message,
  String? placeLabel,
  double? latitude,
  double? longitude,
}) {
  final update = EventLiveUpdate(
    id: 'mock-live-${_mockLiveUpdates.length + 1}',
    calendarEventId: eventId,
    userId: userId,
    authorHandle: authorHandle,
    message: message.trim(),
    createdAt: DateTime.now(),
    placeLabel: placeLabel?.trim().isEmpty ?? true ? null : placeLabel?.trim(),
    latitude: latitude,
    longitude: longitude,
  );
  _mockLiveUpdates.insert(0, update);
  return update;
}

DateTime? mockLastPostAt({
  required String eventId,
  required String userId,
}) {
  for (final update in _mockLiveUpdates) {
    if (update.calendarEventId == eventId && update.userId == userId) {
      return update.createdAt;
    }
  }
  return null;
}

String mockMapsUrl(double lat, double lng) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

String mockMapsUrlForLabel(String label) =>
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(label)}';

bool mockCoordsLookValid(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  return lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0);
}

double mockRandomCoord(double center, double spread) =>
    center + (Random().nextDouble() * 2 - 1) * spread;
