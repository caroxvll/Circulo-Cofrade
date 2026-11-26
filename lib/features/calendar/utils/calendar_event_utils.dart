import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
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

DateTime calendarDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// Último día inclusive. Null si el acto es de una sola jornada.
DateTime? eventSpanEndDay(CalendarEvent event) {
  if (!event.type.allowsDateSpan) return null;
  final until = event.spanUntil;
  if (until == null) return null;
  final last = calendarDay(until);
  final first = calendarDay(event.date);
  if (!last.isAfter(first)) return null;
  return last;
}

bool eventCoversDay(CalendarEvent event, DateTime day) {
  final target = calendarDay(day);
  final first = calendarDay(event.date);
  if (target == first) return true;
  final last = eventSpanEndDay(event);
  if (last == null) return false;
  return !target.isBefore(first) && !target.isAfter(last);
}

/// El acto pisa el intervalo [start, end).
bool eventOverlapsRange(CalendarEvent event, DateTime start, DateTime end) {
  final first = calendarDay(event.date);
  final last = eventSpanEndDay(event) ?? first;
  final rangeStart = calendarDay(start);
  final rangeEnd = calendarDay(end);
  return first.isBefore(rangeEnd) && !last.isBefore(rangeStart);
}

/// Cómo se dibuja el tramo en la celda de ese día.
enum EventSpanEdge { start, middle, end }

EventSpanEdge? eventSpanEdgeOn(CalendarEvent event, DateTime day) {
  final last = eventSpanEndDay(event);
  if (last == null || !eventCoversDay(event, day)) return null;
  final target = calendarDay(day);
  final first = calendarDay(event.date);
  final continuesBefore = target.isAfter(first);
  final continuesAfter = target.isBefore(last);
  if (continuesBefore && continuesAfter) return EventSpanEdge.middle;
  if (continuesAfter) return EventSpanEdge.start;
  if (continuesBefore) return EventSpanEdge.end;
  return null;
}

String formatEventWhenLabel(CalendarEvent event) {
  final last = eventSpanEndDay(event);
  if (last == null) {
    final formatted = DateFormat("EEEE d 'de' MMMM", 'es').format(event.date);
    if (formatted.isEmpty) return formatted;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }
  final first = calendarDay(event.date);
  if (first.year == last.year && first.month == last.month) {
    final month = DateFormat('MMMM', 'es').format(last);
    return 'Del ${first.day} al ${last.day} de $month';
  }
  final from = DateFormat("d 'de' MMMM", 'es').format(first);
  final to = DateFormat("d 'de' MMMM yyyy", 'es').format(last);
  return 'Del $from al $to';
}

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
  final dayEvents = events.where((e) => eventCoversDay(e, date)).toList();
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

enum CalendarEventTimingKind { inProgress, startsSoon, scheduled, finished }

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
      // Estimación para “en curso” / fin de ventana en la app (no es duración real del cortejo).
      EventType.procesion => const Duration(hours: 4),
      EventType.gloria => const Duration(hours: 2),
      EventType.ensayo => const Duration(hours: 4),
      EventType.iguala => const Duration(hours: 4),
      EventType.concierto => const Duration(hours: 2),
      EventType.culto => const Duration(hours: 2),
      EventType.besamanos => const Duration(hours: 2),
      EventType.besapies => const Duration(hours: 2),
      EventType.quinario => const Duration(hours: 2),
      EventType.triduo => const Duration(hours: 2),
      EventType.pregon => const Duration(hours: 2),
      EventType.traslado => const Duration(hours: 2),
      EventType.muda => const Duration(hours: 2),
      EventType.desarma => const Duration(hours: 2),
      EventType.retranqueo => const Duration(hours: 2),
      EventType.viaCrucis => const Duration(hours: 2),
      EventType.viaCrucisConsejo => const Duration(hours: 2),
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
  final span = eventSpanEndDay(event);
  if (span != null) {
    final windows = _eventWindows(event, onDay: span);
    if (windows.isNotEmpty) return windows.last.end;
    return DateTime(span.year, span.month, span.day, 23, 59);
  }
  if (event.endsAt != null) return event.endsAt;
  final start = eventStartDateTime(event);
  if (start == null) return null;
  return start.add(calendarEventDuration(event.type));
}

String formatEventClockTime(DateTime dateTime) {
  final hours = dateTime.hour.toString().padLeft(2, '0');
  final minutes = dateTime.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

/// ¿El live admite avisos ahora? (alineado con SQL can_post_event_live_update).
bool eventLiveAllowsPosting(CalendarEvent event, {DateTime? now}) {
  if (!event.isPublished) return false;
  switch (event.liveForceState) {
    case EventLiveForceState.closed:
      return false;
    case EventLiveForceState.open:
      return true;
    case EventLiveForceState.auto:
      final timing = calendarEventTiming(event, now: now);
      return timing?.kind == CalendarEventTimingKind.inProgress;
  }
}

/// Estado temporal del evento (solo relevante el día de hoy).
CalendarEventTiming? calendarEventTiming(
  CalendarEvent event, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  if (!eventCoversDay(event, today)) {
    return null;
  }

  if (event.liveForceState == EventLiveForceState.closed) {
    return const CalendarEventTiming(
      kind: CalendarEventTimingKind.finished,
      label: 'Finalizado',
      color: AppColors.textMuted,
    );
  }

  final windows = _eventWindows(event, onDay: today);
  if (windows.isEmpty) return null;
  final start = windows.first.start;

  if (event.liveForceState == EventLiveForceState.open) {
    if (clock.isBefore(start)) {
      return const CalendarEventTiming(
        kind: CalendarEventTimingKind.inProgress,
        label: 'En curso',
        color: AppColors.liveGreen,
      );
    }
  }

  for (final window in windows) {
    if (!clock.isBefore(window.start) && clock.isBefore(window.end)) {
      return const CalendarEventTiming(
        kind: CalendarEventTimingKind.inProgress,
        label: 'En curso',
        color: AppColors.liveGreen,
      );
    }
  }

  final next = windows.cast<_EventWindow?>().firstWhere(
        (window) => clock.isBefore(window!.start),
        orElse: () => null,
      );
  if (next != null) {
    final diff = next.start.difference(clock);
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
        color: AppColors.goldDark,
      );
    }
    return const CalendarEventTiming(
      kind: CalendarEventTimingKind.scheduled,
      label: 'Programado',
      color: AppColors.textSecondary,
    );
  }

  return const CalendarEventTiming(
    kind: CalendarEventTimingKind.finished,
    label: 'Finalizado',
    color: AppColors.textMuted,
  );
}

class _EventWindow {
  const _EventWindow({required this.start, required this.end, required this.label});

  final DateTime start;
  final DateTime end;
  final String label;
}

List<_EventWindow> _eventWindows(CalendarEvent event, {DateTime? onDay}) {
  final fallback = _defaultEventDuration(event.type);
  final day = onDay == null
      ? DateTime(event.date.year, event.date.month, event.date.day)
      : DateTime(onDay.year, onDay.month, onDay.day);
  if (event.slots.isEmpty) {
    final startMinutes = timeStringToMinutes(event.time);
    if (startMinutes == null) return const [];
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    final end = eventSpanEndDay(event) == null && event.endsAt != null
        ? event.endsAt!
        : start.add(fallback);
    if (!end.isAfter(start)) return const [];
    return [
      _EventWindow(start: start, end: end, label: event.time ?? ''),
    ];
  }

  final windows = <_EventWindow>[];
  for (final slot in event.slots) {
    final startMin = timeStringToMinutes(slot.start);
    if (startMin == null) continue;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startMin ~/ 60,
      startMin % 60,
    );
    final endMin = timeStringToMinutes(slot.end);
    final end = endMin != null
        ? DateTime(
            day.year,
            day.month,
            day.day,
            endMin ~/ 60,
            endMin % 60,
          )
        : start.add(fallback);
    if (!end.isAfter(start)) continue;
    windows.add(_EventWindow(start: start, end: end, label: slot.start));
  }
  windows.sort((a, b) => a.start.compareTo(b.start));
  return windows;
}

/// Hora de la miniatura: el tramo en curso, si no el siguiente, si no el primero.
String? eventThumbTime(CalendarEvent event, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final windows = _eventWindows(
    event,
    onDay: eventCoversDay(event, today) ? today : null,
  );
  if (windows.isEmpty) return event.time;
  if (!eventCoversDay(event, today)) {
    return windows.first.label.isEmpty ? event.time : windows.first.label;
  }
  for (final window in windows) {
    if (!clock.isBefore(window.start) && clock.isBefore(window.end)) {
      return window.label;
    }
  }
  for (final window in windows) {
    if (clock.isBefore(window.start)) return window.label;
  }
  return windows.first.label.isEmpty ? event.time : windows.first.label;
}

/// Línea con todos los tramos. Null si solo hay una hora de inicio.
String? eventScheduleLabel(CalendarEvent event) {
  final slots = event.slots;
  if (slots.isEmpty) return null;
  final hasRange = slots.any((slot) => (slot.end ?? '').isNotEmpty);
  if (slots.length < 2 && !hasRange) return null;
  return slots.map((slot) => slot.label).join(' · ');
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
            eventOverlapsRange(
              e,
              DateTime(month.year, month.month, 1),
              DateTime(month.year, month.month + 1, 1),
            ) &&
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
  if (message.contains('subtitle') ||
      message.contains('calendar_events_subtitle')) {
    return 'La descripción es demasiado larga (máximo 1000 caracteres).';
  }
  if (message.contains('title') && message.contains('check')) {
    return 'El título debe tener entre 3 y 120 caracteres.';
  }
  if (message.contains('location') && message.contains('check')) {
    return 'El lugar no puede superar 160 caracteres.';
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
