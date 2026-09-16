import '../../../shared/models/calendar_event.dart';
import '../data/calendar_repository.dart';
import '../models/calendar_focus_request.dart';

DateTime? parseNotificationEventStartsAt(Object? raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

Future<CalendarFocusRequest?> buildCalendarFocusFromNotification({
  required CalendarRepository repo,
  String? eventId,
  DateTime? startsAt,
}) async {
  CalendarEvent? event;
  if (eventId != null && eventId.isNotEmpty) {
    event = await repo.fetchById(eventId);
  }

  final date = event?.date ?? startsAt;
  if (date == null) return null;

  return CalendarFocusRequest(
    month: DateTime(date.year, date.month),
    day: date.day,
    event: event,
  );
}

bool isCalendarNotificationData(Map<String, dynamic> data) {
  final route = data['route'];
  if (route == '/calendario') return true;
  final eventId = data['eventId'];
  return eventId is String && eventId.isNotEmpty;
}
