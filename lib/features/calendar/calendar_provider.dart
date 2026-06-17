import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/calendar_event.dart';
import '../../shared/models/user_role.dart';
import '../profile/profile_provider.dart';
import 'data/calendar_repository.dart';
import 'models/calendar_focus_request.dart';
import 'models/calendar_upcoming_snapshot.dart';
import 'utils/calendar_event_utils.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return createCalendarRepository();
});

/// Navegación desde Buscar u otras pantallas hacia un día/evento concreto.
class CalendarFocusNotifier extends Notifier<CalendarFocusRequest?> {
  @override
  CalendarFocusRequest? build() => null;

  void setFocus(CalendarFocusRequest? request) => state = request;

  CalendarFocusRequest? take() {
    final current = state;
    state = null;
    return current;
  }
}

final calendarFocusRequestProvider =
    NotifierProvider<CalendarFocusNotifier, CalendarFocusRequest?>(
  CalendarFocusNotifier.new,
);

final calendarEventsProvider =
    FutureProvider.autoDispose.family<List<CalendarEvent>, DateTime>(
  (ref, month) async {
    final normalized = DateTime(month.year, month.month);
    return ref.watch(calendarRepositoryProvider).fetchForMonth(normalized);
  },
);

final calendarUpcomingProvider =
    FutureProvider.autoDispose<CalendarUpcomingSnapshot>((ref) async {
  final repo = ref.watch(calendarRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dayAfterTomorrow = today.add(const Duration(days: 2));

  final events = await repo.fetchBetween(today, dayAfterTomorrow);
  final tomorrow = today.add(const Duration(days: 1));

  return CalendarUpcomingSnapshot(
    todayEvents: events.where((e) => isSameCalendarDay(e.date, today)).toList(),
    tomorrowEvents:
        events.where((e) => isSameCalendarDay(e.date, tomorrow)).toList(),
  );
});

final calendarHasEventTodayProvider = Provider<bool>((ref) {
  return ref.watch(calendarUpcomingProvider).maybeWhen(
        data: (s) => s.hasEventToday,
        orElse: () => false,
      );
});

final isCalendarEditorProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  if (profile == null || profile.isSuspended) return false;
  return profile.role.canEditCalendar;
});

final isCalendarAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return profile?.role == UserRole.admin;
});

void invalidateCalendarData(WidgetRef ref, DateTime month) {
  ref.invalidate(calendarEventsProvider(DateTime(month.year, month.month)));
  ref.invalidate(calendarUpcomingProvider);
}

void invalidateCalendarMonth(WidgetRef ref, DateTime month) {
  invalidateCalendarData(ref, month);
}
