import '../../../shared/models/calendar_event.dart';

/// Eventos de hoy y mañana para avisos en pantalla y badge del tab.
class CalendarUpcomingSnapshot {
  const CalendarUpcomingSnapshot({
    required this.todayEvents,
    required this.tomorrowEvents,
  });

  final List<CalendarEvent> todayEvents;
  final List<CalendarEvent> tomorrowEvents;

  bool get hasEventToday => todayEvents.isNotEmpty;
  bool get hasEventTomorrow => tomorrowEvents.isNotEmpty;
  bool get hasAny => hasEventToday || hasEventTomorrow;
}
