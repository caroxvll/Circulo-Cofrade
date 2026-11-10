import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/utils/local_day.dart';
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
  ref.watch(calendarEventsEpochProvider);
  final calendarRepo = ref.watch(calendarRepositoryProvider);
  return calendarRepo.fetchTodayEnsayos();
});

const cuaresmaAgendaTypes = {
  EventType.ensayo,
  EventType.iguala,
  EventType.concierto,
  EventType.traslado,
  EventType.muda,
  EventType.desarma,
  EventType.retranqueo,
  EventType.viaCrucis,
  EventType.viaCrucisConsejo,
};

/// Ensayos, igualás y conciertos publicados de hoy.
final todayCuaresmaAgendaProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  ref.watch(calendarEventsEpochProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final events = await ref.watch(calendarRepositoryProvider).fetchBetween(
        today,
        today.add(const Duration(days: 1)),
      );
  return [
    for (final event in events)
      if (cuaresmaAgendaTypes.contains(event.type)) event,
  ];
});

/// Los de hoy que aún se pueden seguir, para la banda de Para ti.
final todayParaTiLiveEventsProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  final events = await ref.watch(todayCuaresmaAgendaProvider.future);
  final groups = groupTodayEnsayos(events);
  return [...groups.live, ...groups.soon, ...groups.upcoming];
});

/// Avisos de hoy de las citas con hilo. Al día siguiente ya no entran en Para ti.
final todayCuaresmaLiveTweetsProvider =
    FutureProvider.autoDispose<List<EventLiveUpdate>>((ref) async {
  final events = await ref.watch(todayCuaresmaAgendaProvider.future);
  final ids = [
    for (final event in events)
      if (event.type.opensCuaresmaLive && event.id != null) event.id!,
  ];
  return ref.watch(eventLiveUpdatesRepositoryProvider).fetchForEvents(
        ids,
        limit: paraTiRiverLimit,
      );
});

/// Feed del ensayo con parches Realtime (sin refetch total por cada aviso).
final eventLiveUpdatesProvider = AsyncNotifierProvider.autoDispose
    .family<EventLiveUpdatesNotifier, List<EventLiveUpdate>, String>(
  EventLiveUpdatesNotifier.new,
);

class EventLiveUpdatesNotifier extends AsyncNotifier<List<EventLiveUpdate>> {
  EventLiveUpdatesNotifier(this.eventId);

  final String eventId;

  static const _maxItems = liveJornadaCap;

  @override
  Future<List<EventLiveUpdate>> build() {
    return ref.watch(eventLiveUpdatesRepositoryProvider).fetchForEvent(eventId);
  }

  Future<void> reload({bool quiet = false}) async {
    if (!quiet) state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(eventLiveUpdatesRepositoryProvider).fetchForEvent(eventId),
    );
  }

  void upsert(EventLiveUpdate update) {
    final current = state.asData?.value;
    if (current == null) return;
    final without = current.where((u) => u.id != update.id);
    final merged = [update, ...without]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(merged.take(_maxItems).toList(growable: false));
  }

  void removeById(String id) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.where((u) => u.id != id).toList(growable: false),
    );
  }

  void applyRealtimePayload(PostgresChangePayload payload) {
    final repo = ref.read(eventLiveUpdatesRepositoryProvider);
    switch (payload.eventType) {
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) removeById(id);
        return;
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = payload.newRecord['id']?.toString();
        if (id == null || id.isEmpty) return;
        EventLiveUpdate? previous;
        for (final u in state.asData?.value ?? const <EventLiveUpdate>[]) {
          if (u.id == id) {
            previous = u;
            break;
          }
        }
        final parsed = repo.fromRealtimeRecord(
          Map<String, dynamic>.from(payload.newRecord),
          previous: previous,
        );
        if (parsed == null || parsed.message.isEmpty) return;
        if (parsed.calendarEventId != eventId) return;
        upsert(parsed);
        return;
      case PostgresChangeEvent.all:
        return;
    }
  }
}

/// Realtime filtrado por ensayo abierto.
final eventLiveUpdatesRealtimeProvider = Provider.autoDispose.family<void, String>((
  ref,
  eventId,
) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  final channel = client
      .channel('event-live-$eventId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_live_updates',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'calendar_event_id',
          value: eventId,
        ),
        callback: (payload) {
          ref
              .read(eventLiveUpdatesProvider(eventId).notifier)
              .applyRealtimePayload(payload);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

String ensayoLiveStatusLabel(CalendarEvent event, {DateTime? now}) =>
    ensayoStatusLabel(event, now: now);
