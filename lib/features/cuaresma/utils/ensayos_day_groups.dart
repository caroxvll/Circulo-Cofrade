import 'package:flutter/material.dart';

import '../../../shared/models/calendar_event.dart';
import '../../calendar/utils/calendar_event_utils.dart';

enum EnsayoDayBucket { live, soon, upcoming, finished }

class EnsayosDayGroups {
  const EnsayosDayGroups({
    required this.live,
    required this.soon,
    required this.upcoming,
    required this.finished,
  });

  final List<CalendarEvent> live;
  final List<CalendarEvent> soon;
  final List<CalendarEvent> upcoming;
  final List<CalendarEvent> finished;

  int get total =>
      live.length + soon.length + upcoming.length + finished.length;

  static const maxFeaturedCount = 10;

  List<CalendarEvent> get featured {
    final cap = maxFeaturedCount;
    final slots = cap - live.length;
    if (slots <= 0) return live.take(cap).toList();
    return [...live, ...soon.take(slots)];
  }

  List<CalendarEvent> get compactList {
    final overflowSoon = soon.skip(
      (maxFeaturedCount - live.length).clamp(0, soon.length),
    );
    return [...overflowSoon, ...upcoming];
  }

  bool get hasFeatured => featured.isNotEmpty;
}

EnsayosDayGroups groupTodayEnsayos(
  List<CalendarEvent> ensayos, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final live = <CalendarEvent>[];
  final soon = <CalendarEvent>[];
  final upcoming = <CalendarEvent>[];
  final finished = <CalendarEvent>[];

  for (final event in ensayos) {
    final bucket = _bucketFor(event, clock);
    switch (bucket) {
      case EnsayoDayBucket.live:
        live.add(event);
      case EnsayoDayBucket.soon:
        soon.add(event);
      case EnsayoDayBucket.upcoming:
        upcoming.add(event);
      case EnsayoDayBucket.finished:
        finished.add(event);
    }
  }

  live.sort(compareCalendarEventsByStart);
  soon.sort(compareCalendarEventsByStart);
  upcoming.sort(compareCalendarEventsByStart);
  finished.sort(compareCalendarEventsByStart);

  return EnsayosDayGroups(
    live: live,
    soon: soon,
    upcoming: upcoming,
    finished: finished,
  );
}

EnsayoDayBucket _bucketFor(CalendarEvent event, DateTime clock) {
  final timing = calendarEventTiming(event, now: clock);
  if (timing != null) {
    return switch (timing.kind) {
      CalendarEventTimingKind.inProgress => EnsayoDayBucket.live,
      CalendarEventTimingKind.startsSoon => EnsayoDayBucket.soon,
      CalendarEventTimingKind.scheduled => EnsayoDayBucket.upcoming,
    };
  }

  final start = eventStartDateTime(event);
  if (start != null &&
      isSameCalendarDay(
        event.date,
        DateTime(clock.year, clock.month, clock.day),
      )) {
    final end = start.add(const Duration(hours: 2));
    if (!clock.isBefore(end)) return EnsayoDayBucket.finished;
  }

  return EnsayoDayBucket.upcoming;
}

String ensayoStatusLabel(CalendarEvent event, {DateTime? now}) {
  final timing = calendarEventTiming(event, now: now);
  if (timing != null) return timing.label;
  final bucket = _bucketFor(event, now ?? DateTime.now());
  return switch (bucket) {
    EnsayoDayBucket.finished => 'Finalizado',
    _ => 'Programado',
  };
}

Color? ensayoStatusColor(CalendarEvent event, {DateTime? now}) {
  final timing = calendarEventTiming(event, now: now);
  if (timing != null) return timing.color;
  final bucket = _bucketFor(event, now ?? DateTime.now());
  return switch (bucket) {
    EnsayoDayBucket.finished => const Color(0xFF9E9E9E),
    _ => const Color(0xFF757575),
  };
}

String ensayoCompactSubtitle(CalendarEvent event) {
  if (event.organizerLabel != null && event.organizerLabel!.isNotEmpty) {
    return event.organizerLabel!;
  }
  if (event.location != null && event.location!.isNotEmpty) {
    return event.location!;
  }
  return 'Ensayo';
}
