import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/calendar_event.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/utils/calendar_event_utils.dart';

/// Próximos eventos de tipo gloria (ventana ~90 días).
final gloriasUpcomingEventsProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  final repo = ref.watch(calendarRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 90));
  final events = await repo.fetchBetween(start, end);
  return events
      .where(
        (e) =>
            e.status == CalendarEventStatus.published &&
            e.type == EventType.gloria,
      )
      .toList()
    ..sort(compareCalendarEventsByStart);
});
