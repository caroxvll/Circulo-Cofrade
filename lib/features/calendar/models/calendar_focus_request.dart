import '../../../shared/models/calendar_event.dart';

/// Petición para abrir el calendario en un día concreto (p. ej. desde Buscar).
class CalendarFocusRequest {
  const CalendarFocusRequest({
    required this.month,
    required this.day,
    this.event,
  });

  final DateTime month;
  final int day;
  final CalendarEvent? event;
}
