import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/models/calendar_event.dart';
import '../admin/admin_provider.dart';
import '../auth/auth_provider.dart';
import '../permissions/permissions_provider.dart';
import '../profile/profile_provider.dart';
import 'data/calendar_repository.dart';
import 'models/calendar_focus_request.dart';
import 'models/calendar_upcoming_snapshot.dart';
import 'models/organizer_logo.dart';
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
    todayEvents: events
        .where((e) => isSameCalendarDay(e.date, today))
        .toList()
      ..sort(compareCalendarEventsByStart),
    tomorrowEvents: events
        .where((e) => isSameCalendarDay(e.date, tomorrow))
        .toList()
      ..sort(compareCalendarEventsByStart),
  );
});

final calendarHasEventTodayProvider = Provider<bool>((ref) {
  return ref.watch(calendarUpcomingProvider).maybeWhen(
        data: (s) => s.hasEventToday,
        orElse: () => false,
      );
});

/// Moderadores de foro o admin pueden proponer eventos (con aprobación si no es admin).
final isCalendarEditorProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  if (profile == null || profile.isSuspended) return false;
  return ref.watch(isJuntaMemberProvider);
});

final isCalendarAdminProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider);
});

/// Escudos de la biblioteca, indexados por clave normalizada del organizador.
final organizerLogosMapProvider =
    FutureProvider<Map<String, OrganizerLogo>>((ref) async {
  final items = await ref
      .read(calendarRepositoryProvider)
      .searchOrganizerLogos('', limit: 300);
  return {for (final item in items) item.organizerKey: item};
});

/// Evento publicado por id (p. ej. patrocinio vinculado al calendario).
final calendarEventByIdProvider =
    FutureProvider.autoDispose.family<CalendarEvent?, String>((ref, eventId) async {
  final trimmed = eventId.trim();
  if (trimmed.isEmpty) return null;
  return ref.watch(calendarRepositoryProvider).fetchById(trimmed);
});

/// Eventos publicados próximos para vincular patrocinios en admin.
final sponsorshipEventPickerProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  final repo = ref.watch(calendarRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 120));
  final events = await repo.fetchBetween(start, end);
  return events
      .where((event) => event.status == CalendarEventStatus.published)
      .toList()
    ..sort(compareCalendarEventsByStart);
});

void invalidateOrganizerLogos(WidgetRef ref) {
  ref.invalidate(organizerLogosMapProvider);
}

void invalidateCalendarData(WidgetRef ref, DateTime month) {
  ref.invalidate(calendarEventsProvider(DateTime(month.year, month.month)));
  ref.invalidate(calendarUpcomingProvider);
}

void invalidateCalendarMonth(WidgetRef ref, DateTime month) {
  invalidateCalendarData(ref, month);
}

/// Recarga calendario (y pendientes de Junta si es admin) tras cambios en Supabase.
void refreshCalendarFromRemote(Ref ref) {
  ref.invalidate(calendarUpcomingProvider);
  ref.invalidate(calendarEventsProvider);
  if (ref.read(isAdminProvider)) {
    ref.invalidate(pendingCalendarEventsProvider);
  }
}

/// Suscripción Realtime: nuevos eventos publicados, aprobaciones, etc.
final calendarRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(calendarRepositoryProvider);
  if (user == null || !repo.isRemote) return;

  final client = SupabaseBootstrap.client;
  if (client == null) return;

  final channel = client
      .channel('calendar-events-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'calendar_events',
        callback: (_) => refreshCalendarFromRemote(ref),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});
