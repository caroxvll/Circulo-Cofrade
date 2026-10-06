import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/models/calendar_event.dart';
import '../admin/admin_provider.dart';
import '../auth/auth_provider.dart';
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

/// Epoch para que Cuaresma/otros refresquen ensayos del día sin import circular.
class CalendarEventsEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final calendarEventsEpochProvider =
    NotifierProvider<CalendarEventsEpochNotifier, int>(
  CalendarEventsEpochNotifier.new,
);

final calendarEventsProvider =
    FutureProvider.autoDispose.family<List<CalendarEvent>, DateTime>(
  (ref, month) async {
    ref.keepAlive();
    final normalized = DateTime(month.year, month.month);
    return ref.watch(calendarRepositoryProvider).fetchForMonth(normalized);
  },
);

final calendarUpcomingProvider =
    FutureProvider.autoDispose<CalendarUpcomingSnapshot>((ref) async {
  ref.keepAlive();
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

/// Escudos de la biblioteca + escudos de tablones de hermandad.
/// La biblioteca tiene prioridad; el tablón rellena huecos.
final organizerLogosMapProvider =
    FutureProvider<Map<String, OrganizerLogo>>((ref) async {
  final repo = ref.read(calendarRepositoryProvider);
  final items = await repo.searchOrganizerLogos('', limit: 300);
  final fromLibrary = {for (final item in items) item.organizerKey: item};
  final fromBoards = await repo.fetchHermandadOrganizerLogos();
  return {...fromBoards, ...fromLibrary};
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

/// Recarga amplia (pull-to-refresh / fallback si el payload viene incompleto).
void refreshCalendarFromRemote(Ref ref) {
  ref.invalidate(calendarUpcomingProvider);
  ref.invalidate(calendarEventsProvider);
  ref.read(calendarEventsEpochProvider.notifier).bump();
  if (ref.read(isAdminProvider)) {
    ref.invalidate(pendingCalendarEventsProvider);
  }
}

DateTime? _parseStartsAt(Map<String, dynamic> record) {
  final raw = record['starts_at']?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

bool _touchesUpcomingWindow(DateTime starts) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(starts.year, starts.month, starts.day);
  final from = today.subtract(const Duration(days: 1));
  final to = today.add(const Duration(days: 2));
  return !day.isBefore(from) && !day.isAfter(to);
}

/// Invalidación acotada: solo meses / upcoming afectados por el evento.
void refreshCalendarFromRemotePayload(Ref ref, PostgresChangePayload payload) {
  final newRecord = payload.newRecord;
  final oldRecord = payload.oldRecord;
  final record = newRecord.isNotEmpty ? newRecord : oldRecord;

  final id = record['id']?.toString();
  if (id != null && id.isNotEmpty) {
    ref.invalidate(calendarEventByIdProvider(id));
  }

  final months = <DateTime>{};
  final newStarts = _parseStartsAt(newRecord);
  final oldStarts = _parseStartsAt(oldRecord);
  if (newStarts != null) {
    months.add(DateTime(newStarts.year, newStarts.month));
  }
  if (oldStarts != null) {
    months.add(DateTime(oldStarts.year, oldStarts.month));
  }

  if (months.isEmpty) {
    refreshCalendarFromRemote(ref);
    return;
  }

  for (final month in months) {
    ref.invalidate(calendarEventsProvider(month));
  }

  final touchesUpcoming = (newStarts != null && _touchesUpcomingWindow(newStarts)) ||
      (oldStarts != null && _touchesUpcomingWindow(oldStarts));
  if (touchesUpcoming) {
    ref.invalidate(calendarUpcomingProvider);
  }

  final eventType = (newRecord['event_type'] ?? oldRecord['event_type'])
      ?.toString();
  if (eventType == 'ensayo' ||
      newRecord.containsKey('live_force_state') ||
      oldRecord.containsKey('live_force_state')) {
    ref.read(calendarEventsEpochProvider.notifier).bump();
  }

  final statusChanged = payload.eventType == PostgresChangeEvent.update &&
      oldRecord['status']?.toString() != newRecord['status']?.toString();
  if (ref.read(isAdminProvider) &&
      (statusChanged ||
          payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.delete)) {
    ref.invalidate(pendingCalendarEventsProvider);
  }
}

/// Suscripción Realtime: acumula payloads en ventana corta (no “last wins”).
final calendarRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(calendarRepositoryProvider);
  if (user == null || !repo.isRemote) return;

  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? debounce;
  final pending = <PostgresChangePayload>[];

  void schedule(PostgresChangePayload payload) {
    pending.add(payload);
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 220), () {
      final batch = List<PostgresChangePayload>.from(pending);
      pending.clear();
      if (batch.isEmpty) return;

      var needsFull = false;
      for (final p in batch) {
        final record = p.newRecord.isNotEmpty ? p.newRecord : p.oldRecord;
        final hasStarts = _parseStartsAt(p.newRecord) != null ||
            _parseStartsAt(p.oldRecord) != null;
        if (record['id'] == null && !hasStarts) {
          needsFull = true;
          break;
        }
      }
      if (needsFull) {
        refreshCalendarFromRemote(ref);
        return;
      }
      for (final p in batch) {
        refreshCalendarFromRemotePayload(ref, p);
      }
    });
  }

  final channel = client
      .channel('calendar-events-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'calendar_events',
        callback: schedule,
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});
