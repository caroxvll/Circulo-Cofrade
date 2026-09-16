import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/calendar_event.dart';
import '../models/organizer_logo.dart';

class CalendarEventDeleteFailedException implements Exception {
  const CalendarEventDeleteFailedException();
}

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
  return eventsOnDate(
    events,
    DateTime(month.year, month.month, day),
  );
}

List<CalendarEvent> eventsOnDate(
  List<CalendarEvent> events,
  DateTime date,
) {
  final dayEvents = events
      .where((e) => isSameCalendarDay(e.date, date))
      .toList();
  dayEvents.sort(compareCalendarEventsByStart);
  return dayEvents;
}

/// Lunes de la semana que contiene [date] (semana ISO, lunes = inicio).
DateTime startOfWeek(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final weekday = normalized.weekday;
  return normalized.subtract(Duration(days: weekday - DateTime.monday));
}

List<DateTime> weekDaysContaining(DateTime date) {
  final start = startOfWeek(date);
  return List.generate(
    7,
    (i) => start.add(Duration(days: i)),
  );
}

/// Clave estable para agrupar escudos de la misma hermandad/banda.
String normalizeOrganizerKey(String raw) {
  var value = raw.toLowerCase().trim();
  value = value.replaceAll(RegExp(r'\s+'), ' ');
  value = value.replaceAll(RegExp(r'[.]+'), '.');
  return value;
}

OrganizerLogo? organizerLogoForEvent(
  Map<String, OrganizerLogo>? logosByKey,
  CalendarEvent event,
) {
  final label = event.organizerLabel?.trim();
  if (logosByKey == null || label == null || label.isEmpty) return null;
  final key = normalizeOrganizerKey(label);
  if (key.length < 2) return null;
  return logosByKey[key];
}

String? resolvedOrganizerLabel(
  Map<String, OrganizerLogo>? logosByKey,
  CalendarEvent event,
) {
  final entry = organizerLogoForEvent(logosByKey, event);
  if (entry != null && entry.displayLabel.trim().isNotEmpty) {
    return entry.displayLabel.trim();
  }
  final label = event.organizerLabel?.trim();
  return label != null && label.isNotEmpty ? label : null;
}

String? resolvedOrganizerShieldUrl(
  Map<String, OrganizerLogo>? logosByKey,
  CalendarEvent event,
) {
  final entry = organizerLogoForEvent(logosByKey, event);
  if (entry != null && entry.hasLogo) return entry.logoUrl;
  final url = event.customIconUrl?.trim();
  return url != null && url.isNotEmpty ? url : null;
}

int compareCalendarEventsByStart(CalendarEvent a, CalendarEvent b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final aMinutes = _timeToMinutes(a.time);
  final bMinutes = _timeToMinutes(b.time);
  if (aMinutes != null && bMinutes != null && aMinutes != bMinutes) {
    return aMinutes.compareTo(bMinutes);
  }
  return a.title.compareTo(b.title);
}

int? timeStringToMinutes(String? time) {
  if (time == null || !time.contains(':')) return null;
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

int? _timeToMinutes(String? time) => timeStringToMinutes(time);

enum CalendarEventTimingKind { inProgress, startsSoon, scheduled }

class CalendarEventTiming {
  const CalendarEventTiming({
    required this.kind,
    required this.label,
    required this.color,
  });

  final CalendarEventTimingKind kind;
  final String label;
  final Color color;
}

Duration _defaultEventDuration(EventType type) => switch (type) {
      EventType.procesion => const Duration(hours: 4),
      EventType.gloria => const Duration(hours: 2),
      EventType.ensayo => const Duration(hours: 2),
      EventType.iguala => const Duration(hours: 1, minutes: 30),
      EventType.concierto => const Duration(hours: 2),
      EventType.evento => const Duration(hours: 2),
    };

DateTime? eventStartDateTime(CalendarEvent event) {
  final minutes = timeStringToMinutes(event.time);
  if (minutes == null) return null;
  return DateTime(
    event.date.year,
    event.date.month,
    event.date.day,
    minutes ~/ 60,
    minutes % 60,
  );
}

Duration calendarEventDuration(EventType type) => _defaultEventDuration(type);

DateTime? eventEndDateTime(CalendarEvent event) {
  final start = eventStartDateTime(event);
  if (start == null) return null;
  return start.add(calendarEventDuration(event.type));
}

String formatEventClockTime(DateTime dateTime) {
  final hours = dateTime.hour.toString().padLeft(2, '0');
  final minutes = dateTime.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

/// Estado temporal del evento (solo relevante el día de hoy).
CalendarEventTiming? calendarEventTiming(
  CalendarEvent event, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (!isSameCalendarDay(
    event.date,
    DateTime(clock.year, clock.month, clock.day),
  )) {
    return null;
  }

  final start = eventStartDateTime(event);
  if (start == null) return null;

  final end = start.add(_defaultEventDuration(event.type));

  if (!clock.isBefore(start) && clock.isBefore(end)) {
    return const CalendarEventTiming(
      kind: CalendarEventTimingKind.inProgress,
      label: 'En curso',
      color: Color(0xFF2E7D32),
    );
  }

  if (clock.isBefore(start)) {
    final diff = start.difference(clock);
    if (diff <= const Duration(minutes: 90)) {
      final mins = diff.inMinutes;
      final label = mins <= 1
          ? 'Empieza ahora'
          : mins < 60
              ? 'Empieza en $mins min'
              : 'Empieza en ${(mins / 60).ceil()} h';
      return CalendarEventTiming(
        kind: CalendarEventTimingKind.startsSoon,
        label: label,
        color: const Color(0xFFE65100),
      );
    }
    return const CalendarEventTiming(
      kind: CalendarEventTimingKind.scheduled,
      label: 'Programado',
      color: Color(0xFF757575),
    );
  }

  return null;
}

String formatCalendarDayHeading(DateTime date) {
  final formatted = DateFormat("EEEE d 'de' MMMM", 'es').format(date);
  if (formatted.isEmpty) return formatted;
  return formatted[0].toUpperCase() + formatted.substring(1);
}

String formatCalendarMonthLabel(DateTime date) {
  final month = DateFormat('MMMM', 'es').format(date);
  if (month.isEmpty) return month;
  return month[0].toUpperCase() + month.substring(1);
}

String formatCalendarDayEventsSectionTitle(DateTime date) {
  final formatted = DateFormat("EEEE d 'de' MMMM", 'es').format(date);
  if (formatted.isEmpty) return 'Eventos del día';
  final lower = formatted.toLowerCase();
  return 'Eventos del $lower';
}

bool isSameCalendarDayAsToday(DateTime date) {
  final now = DateTime.now();
  return isSameCalendarDay(
    date,
    DateTime(now.year, now.month, now.day),
  );
}

/// True si el evento ya terminó (o su día ya pasó, si no tiene hora).
bool isCalendarEventPast(CalendarEvent event, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final end = eventEndDateTime(event);
  if (end != null) return !clock.isBefore(end);
  final day = DateTime(event.date.year, event.date.month, event.date.day);
  final today = DateTime(clock.year, clock.month, clock.day);
  return day.isBefore(today);
}

/// Etiqueta de día para listas guardadas (Hoy / Mañana / fecha completa).
String formatSavedEventDayLabel(DateTime date, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(clock.year, clock.month, clock.day);
  if (day == today) return 'Hoy';
  if (day == today.add(const Duration(days: 1))) return 'Mañana';
  if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
  return formatCalendarDayHeading(date);
}

/// Agrupa eventos por día civil, preservando el orden de [events].
List<({DateTime day, List<CalendarEvent> events})> groupCalendarEventsByDay(
  List<CalendarEvent> events,
) {
  final groups = <DateTime, List<CalendarEvent>>{};
  final order = <DateTime>[];
  for (final event in events) {
    final day = DateTime(event.date.year, event.date.month, event.date.day);
    if (!groups.containsKey(day)) {
      groups[day] = [];
      order.add(day);
    }
    groups[day]!.add(event);
  }
  return [
    for (final day in order) (day: day, events: groups[day]!),
  ];
}

/// Redondea hacia arriba al siguiente bloque de 15 minutos.
DateTime roundUpToNextQuarterHour(DateTime dateTime) {
  final totalMinutes = dateTime.hour * 60 + dateTime.minute;
  var rounded = ((totalMinutes + 14) ~/ 15) * 15;
  if (rounded >= 24 * 60) rounded = 23 * 60 + 45;
  return DateTime(
    dateTime.year,
    dateTime.month,
    dateTime.day,
    rounded ~/ 60,
    rounded % 60,
  );
}

TimeOfDay defaultTimeForEventDate(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  if (isSameCalendarDayAsToday(day)) {
    final rounded = roundUpToNextQuarterHour(DateTime.now());
    return TimeOfDay(hour: rounded.hour, minute: rounded.minute);
  }
  return const TimeOfDay(hour: 20, minute: 0);
}

void ensureEventTimeNotInPast({
  required DateTime date,
  required TimeOfDay time,
  required void Function(TimeOfDay adjusted) onAdjusted,
}) {
  if (!isSameCalendarDayAsToday(date)) return;

  final startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (!startsAt.isBefore(DateTime.now())) return;

  final rounded = roundUpToNextQuarterHour(DateTime.now());
  onAdjusted(TimeOfDay(hour: rounded.hour, minute: rounded.minute));
}

/// Próximo evento del día; si todos pasaron, el último del listado.
CalendarEvent? featuredEventForDay(List<CalendarEvent> events, {DateTime? now}) {
  if (events.isEmpty) return null;
  final clock = now ?? DateTime.now();
  for (final event in events) {
    if (!event.date.isBefore(clock)) return event;
  }
  return events.last;
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

String calendarSaveErrorMessage(PostgrestException error) {
  final message = error.message.toLowerCase();
  if (error.code == '42501' || message.contains('row-level security')) {
    return 'No tienes permiso para editar este evento.';
  }
  if (message.contains('no tienes permiso para crear eventos')) {
    return 'No tienes permiso para publicar en el calendario.';
  }
  if (error.code == 'PGRST116' ||
      message.contains('0 rows') ||
      message.contains('no rows')) {
    return 'No tienes permiso para editar este evento o ya no existe.';
  }
  return 'No se pudo guardar el evento. Inténtalo de nuevo.';
}

String calendarDeleteErrorMessage(Object error) {
  if (error is CalendarEventDeleteFailedException) {
    return 'No tienes permiso para eliminar este evento o ya no existe.';
  }
  if (error is PostgrestException) {
    return calendarSaveErrorMessage(error)
        .replaceFirst('editar', 'eliminar')
        .replaceFirst('guardar', 'eliminar');
  }
  return 'No se pudo eliminar el evento. Inténtalo de nuevo.';
}
