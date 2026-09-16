import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_provider.dart';
import '../../shared/models/calendar_event.dart';
import 'data/event_live_updates_repository.dart';
import 'models/event_live_update.dart';

import 'utils/ensayos_day_groups.dart';

export 'data/event_live_updates_repository.dart'
    show EventLiveUpdateRateLimitedException;

export 'utils/ensayos_day_groups.dart' show ensayoStatusLabel;

final eventLiveUpdatesRepositoryProvider =
    Provider<EventLiveUpdatesRepository>((ref) {
  return createEventLiveUpdatesRepository();
});

final todayEnsayosProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  final calendarRepo = ref.watch(calendarRepositoryProvider);
  return calendarRepo.fetchTodayEnsayos();
});

final calendarEventByIdProvider =
    FutureProvider.autoDispose.family<CalendarEvent?, String>((ref, eventId) {
  return ref.watch(calendarRepositoryProvider).fetchEventById(eventId);
});

final eventLiveUpdatesProvider =
    FutureProvider.autoDispose.family<List<EventLiveUpdate>, String>(
  (ref, eventId) {
    return ref.watch(eventLiveUpdatesRepositoryProvider).fetchForEvent(eventId);
  },
);

String ensayoLiveStatusLabel(CalendarEvent event, {DateTime? now}) =>
    ensayoStatusLabel(event, now: now);
