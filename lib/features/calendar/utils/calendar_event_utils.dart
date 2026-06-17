import '../../../shared/models/calendar_event.dart';

DateTime calendarDefaultMonth({required bool supabaseReady}) {
  if (supabaseReady) {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }
  return DateTime(2026, 6);
}

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isCurrentCalendarMonth(DateTime month) {
  final now = DateTime.now();
  return month.year == now.year && month.month == now.month;
}

List<CalendarEvent> eventsOnDay(
  List<CalendarEvent> events,
  DateTime month,
  int day,
) {
  return events
      .where(
        (e) =>
            e.date.year == month.year &&
            e.date.month == month.month &&
            e.date.day == day,
      )
      .toList();
}

List<CalendarEvent> eventsForMonth(
  List<CalendarEvent> events,
  DateTime month, {
  EventFilter filter = EventFilter.todas,
}) {
  return events
      .where(
        (e) =>
            e.date.year == month.year &&
            e.date.month == month.month &&
            filter.matches(e),
      )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

bool canManageCalendarEvent({
  required CalendarEvent event,
  required String? currentUserId,
  required bool isAdmin,
}) {
  if (currentUserId == null) return false;
  if (isAdmin) return true;
  final createdBy = event.createdById?.toLowerCase();
  return createdBy != null && createdBy == currentUserId.toLowerCase();
}
