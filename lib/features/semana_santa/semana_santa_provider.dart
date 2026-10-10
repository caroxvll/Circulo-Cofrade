import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_provider.dart';
import 'data/ss_live_engagement_repository.dart';
import 'data/ss_live_gate_repository.dart';
import 'data/ss_live_updates_repository.dart';
import 'models/ss_live_update.dart';
import 'utils/ss_map_logic.dart';

export 'data/ss_live_engagement_repository.dart'
    show SsLiveEngagementSnapshot, SsLiveReply;
export 'data/ss_live_gate_repository.dart'
    show SsLiveGateState, SsLiturgicalDay, ssLiveGateProvider;
export 'data/ss_live_updates_repository.dart'
    show SsLiveUpdateRateLimitedException;
export 'utils/ss_map_logic.dart';

final ssLiveUpdatesRepositoryProvider = Provider<SsLiveUpdatesRepository>((ref) {
  return createSsLiveUpdatesRepository();
});

final ssLiveEngagementRepositoryProvider =
    Provider<SsLiveEngagementRepository>((ref) {
  return createSsLiveEngagementRepository();
});

/// Quién puede pulsar «Informar» en SS (admin, hermandad verificada o allowlist).
final ssCanInformProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final client = SupabaseBootstrap.client;
  if (client == null) return false;
  try {
    final raw = await client.rpc(
      'can_post_ss_live_update',
      params: {'p_user_id': user.id},
    );
    return raw == true;
  } catch (_) {
    return false;
  }
});

enum SsHubViewMode { map, list }

class SsLiveFeedFilterNotifier extends Notifier<SsLiveUpdateKind?> {
  @override
  SsLiveUpdateKind? build() => null;

  void setFilter(SsLiveUpdateKind? kind) => state = kind;
}

class SsHermandadFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setHermandad(String? hermandad) => state = hermandad;
}

class SsHubViewModeNotifier extends Notifier<SsHubViewMode> {
  @override
  SsHubViewMode build() => SsHubViewMode.map;

  void setMode(SsHubViewMode mode) => state = mode;
}

final ssLiveFeedFilterProvider =
    NotifierProvider.autoDispose<SsLiveFeedFilterNotifier, SsLiveUpdateKind?>(
  SsLiveFeedFilterNotifier.new,
);

final ssHermandadFilterProvider =
    NotifierProvider.autoDispose<SsHermandadFilterNotifier, String?>(
  SsHermandadFilterNotifier.new,
);

final ssHubViewModeProvider =
    NotifierProvider.autoDispose<SsHubViewModeNotifier, SsHubViewMode>(
  SsHubViewModeNotifier.new,
);

/// Epoch para refrescar hilos de respuesta abiertos vía Realtime.
final ssLiveRepliesEpochProvider =
    NotifierProvider<SsLiveRepliesEpochNotifier, int>(
  SsLiveRepliesEpochNotifier.new,
);

class SsLiveRepliesEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Feed con parches incrementales (estilo apps pro: no refetch total por evento).
final ssLiveRawFeedProvider =
    AsyncNotifierProvider.autoDispose<SsLiveFeedNotifier, List<SsLiveUpdate>>(
  SsLiveFeedNotifier.new,
);

class SsLiveFeedNotifier extends AsyncNotifier<List<SsLiveUpdate>> {
  static const _maxItems = 80;
  static const _window = Duration(hours: 12);

  @override
  Future<List<SsLiveUpdate>> build() {
    // keepAlive: reentrar al hub no refetcha en frío en la misma sesión.
    ref.keepAlive();
    return ref.watch(ssLiveUpdatesRepositoryProvider).fetchFeed();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ssLiveUpdatesRepositoryProvider).fetchFeed(),
    );
  }

  void upsert(SsLiveUpdate update) {
    final current = state.asData?.value;
    if (current == null) return;
    final without = current.where((u) => u.id != update.id);
    final merged = [update, ...without]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final cutoff = DateTime.now().subtract(_window);
    state = AsyncData(
      merged
          .where((u) => !u.createdAt.isBefore(cutoff))
          .take(_maxItems)
          .toList(growable: false),
    );
  }

  void removeById(String id) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.where((u) => u.id != id).toList(growable: false),
    );
  }

  void applyRealtimePayload(PostgresChangePayload payload) {
    final repo = ref.read(ssLiveUpdatesRepositoryProvider);
    switch (payload.eventType) {
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) removeById(id);
        return;
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = payload.newRecord['id']?.toString();
        if (id == null || id.isEmpty) return;
        SsLiveUpdate? previous;
        for (final u in state.asData?.value ?? const <SsLiveUpdate>[]) {
          if (u.id == id) {
            previous = u;
            break;
          }
        }
        // Solo payload local (0 queries). Sin hydrate masivo a N clientes.
        final parsed = repo.fromRealtimeRecord(
          Map<String, dynamic>.from(payload.newRecord),
          previous: previous,
        );
        if (parsed == null || parsed.message.isEmpty) return;
        upsert(parsed);
        return;
      case PostgresChangeEvent.all:
        return;
    }
  }
}

/// Engagement con parches por aviso (likes/replies no disparan snapshot global).
final ssLiveEngagementProvider = AsyncNotifierProvider.autoDispose<
    SsLiveEngagementNotifier, SsLiveEngagementSnapshot>(
  SsLiveEngagementNotifier.new,
);

class SsLiveEngagementNotifier
    extends AsyncNotifier<SsLiveEngagementSnapshot> {
  /// Memoria updateId+userId → emoji (DELETE de Realtime a veces no trae reaction).
  final Map<String, String> _reactionByActor = {};

  String _actorKey(String updateId, String userId) => '$updateId::$userId';

  void _rememberReaction(String updateId, String userId, String? reaction) {
    final key = _actorKey(updateId, userId);
    if (reaction == null || reaction.isEmpty) {
      _reactionByActor.remove(key);
    } else {
      _reactionByActor[key] = reaction;
    }
  }

  String? _resolveDeletedReaction({
    required String updateId,
    required String actor,
    required String? fromPayload,
    required SsLiveEngagementSnapshot current,
  }) {
    if (fromPayload != null && fromPayload.isNotEmpty) return fromPayload;
    final remembered = _reactionByActor.remove(_actorKey(updateId, actor));
    if (remembered != null && remembered.isNotEmpty) return remembered;
    final bucket = current.countsFor(updateId);
    if (bucket.length == 1) return bucket.keys.first;
    return null;
  }

  Future<void> _resyncReactionCounts(String updateId) async {
    try {
      final counts = await ref
          .read(ssLiveEngagementRepositoryProvider)
          .fetchReactionCountsFor(updateId);
      final current = state.asData?.value;
      if (current == null) return;
      state = AsyncData(current.replaceReactionCounts(updateId, counts));
    } catch (_) {
      // Silencioso: el próximo reload corrige.
    }
  }

  @override
  Future<SsLiveEngagementSnapshot> build() async {
    ref.keepAlive();
    final repo = ref.watch(ssLiveEngagementRepositoryProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    // Espera la primera carga del feed sin re-suscribirse a cada parche.
    final feed = await ref.read(ssLiveRawFeedProvider.future);

    ref.listen(ssLiveRawFeedProvider, (prev, next) {
      final prevIds =
          prev?.asData?.value.map((e) => e.id).toSet() ?? const <String>{};
      final list = next.asData?.value;
      if (list == null) return;
      for (final u in list) {
        if (!prevIds.contains(u.id)) {
          seedUpdate(u.id);
        }
      }
    });

    return repo.fetchSnapshot(
      updateIds: feed.map((u) => u.id).toList(),
      userId: userId,
    );
  }

  Future<void> reload() async {
    final updates = ref.read(ssLiveRawFeedProvider).asData?.value ?? const [];
    final userId = ref.read(currentUserProvider)?.id;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ssLiveEngagementRepositoryProvider).fetchSnapshot(
            updateIds: updates.map((u) => u.id).toList(),
            userId: userId,
          ),
    );
  }

  void seedUpdate(String updateId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.seedUpdate(updateId));
  }

  void applyLikePayload(PostgresChangePayload payload) {
    final current = state.asData?.value;
    if (current == null) return;
    final me = ref.read(currentUserProvider)?.id;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final updateId = payload.newRecord['update_id']?.toString();
        final actor = payload.newRecord['user_id']?.toString();
        final reaction = payload.newRecord['reaction'] as String?;
        if (updateId == null || actor == null) return;
        _rememberReaction(updateId, actor, reaction);
        // Misma cuenta / mismo dispositivo: si el local ya refleja el estado, no sumar 2x.
        // Otra sesión con el mismo user SÍ necesita el parche.
        if (me != null &&
            actor == me &&
            current.userReactionFor(updateId) == reaction) {
          return;
        }
        state = AsyncData(
          current.applyLikeEvent(
            updateId: updateId,
            actorUserId: actor,
            oldReaction: me != null && actor == me
                ? current.userReactionFor(updateId)
                : null,
            newReaction: reaction,
            currentUserId: me,
          ),
        );
        return;
      case PostgresChangeEvent.update:
        final updateId = payload.newRecord['update_id']?.toString();
        final actor = payload.newRecord['user_id']?.toString();
        if (updateId == null || actor == null) return;
        final newReaction = payload.newRecord['reaction'] as String?;
        final oldReaction = payload.oldRecord['reaction'] as String? ??
            _reactionByActor[_actorKey(updateId, actor)];
        _rememberReaction(updateId, actor, newReaction);
        if (me != null &&
            actor == me &&
            current.userReactionFor(updateId) == newReaction) {
          return;
        }
        state = AsyncData(
          current.applyLikeEvent(
            updateId: updateId,
            actorUserId: actor,
            oldReaction: oldReaction ??
                (me != null && actor == me
                    ? current.userReactionFor(updateId)
                    : null),
            newReaction: newReaction,
            currentUserId: me,
          ),
        );
        return;
      case PostgresChangeEvent.delete:
        final updateId = payload.oldRecord['update_id']?.toString();
        final actor = payload.oldRecord['user_id']?.toString();
        if (updateId == null || actor == null) return;
        final oldReaction = _resolveDeletedReaction(
          updateId: updateId,
          actor: actor,
          fromPayload: payload.oldRecord['reaction'] as String?,
          current: current,
        );
        _rememberReaction(updateId, actor, null);
        if (me != null &&
            actor == me &&
            current.userReactionFor(updateId) == null) {
          return;
        }
        if (oldReaction == null &&
            !(me != null && actor == me)) {
          unawaited(_resyncReactionCounts(updateId));
          return;
        }
        state = AsyncData(
          current.applyLikeEvent(
            updateId: updateId,
            actorUserId: actor,
            oldReaction: oldReaction ?? current.userReactionFor(updateId),
            newReaction: null,
            currentUserId: me,
          ),
        );
        return;
      case PostgresChangeEvent.all:
        return;
    }
  }

  final Set<String> _skipReplyDeltaOnce = {};

  void applyReplyPayload(PostgresChangePayload payload) {
    final current = state.asData?.value;
    if (current == null) return;
    final me = ref.read(currentUserProvider)?.id;
    final isDelete = payload.eventType == PostgresChangeEvent.delete;
    final record = isDelete ? payload.oldRecord : payload.newRecord;
    final updateId = record['update_id']?.toString();
    final actor = record['user_id']?.toString();
    if (updateId == null || updateId.isEmpty) return;

    final delta = switch (payload.eventType) {
      PostgresChangeEvent.insert => 1,
      PostgresChangeEvent.delete => -1,
      _ => 0,
    };
    if (delta == 0) return;

    // Dispositivo que publicó: ya sumó en local → no doble conteo.
    // Otra sesión (mismo user): aplica el delta.
    if (me != null && actor == me && !isDelete) {
      ref.read(ssLiveRepliesEpochProvider.notifier).bump();
      if (_skipReplyDeltaOnce.remove(updateId)) return;
      state = AsyncData(current.applyReplyDelta(updateId, delta));
      return;
    }

    state = AsyncData(current.applyReplyDelta(updateId, delta));
    ref.read(ssLiveRepliesEpochProvider.notifier).bump();
  }

  /// Tras reaccionar en local: alinea snapshot sin refetch.
  void applyLocalReaction({
    required String updateId,
    required String userId,
    required String? previous,
    required String? next,
  }) {
    final current = state.asData?.value;
    if (current == null) return;
    _rememberReaction(updateId, userId, next);
    state = AsyncData(
      current.applyLikeEvent(
        updateId: updateId,
        actorUserId: userId,
        oldReaction: previous,
        newReaction: next,
        currentUserId: userId,
      ),
    );
  }

  void applyLocalReplyDelta(String updateId, int delta) {
    final current = state.asData?.value;
    if (current == null) return;
    if (delta > 0) _skipReplyDeltaOnce.add(updateId);
    state = AsyncData(current.applyReplyDelta(updateId, delta));
  }
}

/// Realtime: parchea estado local (no “recarga toda la pizarra”).
final ssLiveRealtimeProvider = Provider<void>((ref) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? gateDebounce;

  void scheduleGateRefresh() {
    gateDebounce?.cancel();
    gateDebounce = Timer(const Duration(milliseconds: 280), () {
      ref.invalidate(ssLiveGateProvider);
    });
  }

  final channel = client
      .channel('ss-live-hub')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ss_live_updates',
        callback: (payload) {
          ref.read(ssLiveRawFeedProvider.notifier).applyRealtimePayload(payload);
          if (payload.eventType == PostgresChangeEvent.insert) {
            final id = payload.newRecord['id']?.toString();
            if (id != null) {
              ref.read(ssLiveEngagementProvider.notifier).seedUpdate(id);
            }
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ss_live_settings',
        callback: (_) => scheduleGateRefresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ss_liturgical_days',
        callback: (_) => scheduleGateRefresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ss_live_update_likes',
        callback: (payload) {
          ref.read(ssLiveEngagementProvider.notifier).applyLikePayload(payload);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ss_live_update_replies',
        callback: (payload) {
          ref.read(ssLiveEngagementProvider.notifier).applyReplyPayload(payload);
        },
      )
      .subscribe();

  ref.onDispose(() {
    gateDebounce?.cancel();
    client.removeChannel(channel);
  });
});

/// Feed filtrado por tipo + hermandad.
final ssLiveFeedProvider =
    Provider.autoDispose<AsyncValue<List<SsLiveUpdate>>>((ref) {
  final raw = ref.watch(ssLiveRawFeedProvider);
  final kind = ref.watch(ssLiveFeedFilterProvider);
  final hermandad = ref.watch(ssHermandadFilterProvider);
  return raw.whenData(
    (updates) => filterSsUpdates(
      updates,
      kind: kind,
      hermandad: hermandad,
    ),
  );
});

final ssLiveStatsProvider = Provider.autoDispose<SsLiveStats>((ref) {
  final updates = ref.watch(ssLiveRawFeedProvider).asData?.value ?? const [];
  return SsLiveStats.fromUpdates(updates);
});

final ssHermandadLabelsProvider = Provider.autoDispose<List<String>>((ref) {
  final updates = ref.watch(ssLiveRawFeedProvider).asData?.value ?? const [];
  return ssHermandadLabels(updates);
});

final ssMapMarkersProvider = Provider.autoDispose<List<SsHermandadTrack>>((ref) {
  final raw = ref.watch(ssLiveRawFeedProvider).asData?.value ?? const [];
  final hermandad = ref.watch(ssHermandadFilterProvider);
  return buildSsHermandadTracks(raw, hermandad: hermandad);
});

final ssLiveRepliesProvider = FutureProvider.autoDispose
    .family<List<SsLiveReply>, String>((ref, updateId) {
  ref.watch(ssLiveRepliesEpochProvider);
  return ref.watch(ssLiveEngagementRepositoryProvider).fetchReplies(updateId);
});
