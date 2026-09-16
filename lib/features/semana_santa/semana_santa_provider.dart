import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'data/ss_live_engagement_repository.dart';
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

/// Feed crudo (sin filtros de UI).
final ssLiveRawFeedProvider =
    FutureProvider.autoDispose<List<SsLiveUpdate>>((ref) {
  return ref.watch(ssLiveUpdatesRepositoryProvider).fetchFeed();
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

/// Reacciones + contadores de respuesta del feed visible.
final ssLiveEngagementProvider =
    FutureProvider.autoDispose<SsLiveEngagementSnapshot>((ref) async {
  final updates = ref.watch(ssLiveRawFeedProvider).asData?.value;
  if (updates == null || updates.isEmpty) {
    return const SsLiveEngagementSnapshot();
  }
  final userId = ref.watch(currentUserProvider)?.id;
  return ref.watch(ssLiveEngagementRepositoryProvider).fetchSnapshot(
        updateIds: updates.map((u) => u.id).toList(),
        userId: userId,
      );
});

final ssLiveRepliesProvider = FutureProvider.autoDispose
    .family<List<SsLiveReply>, String>((ref, updateId) {
  return ref.watch(ssLiveEngagementRepositoryProvider).fetchReplies(updateId);
});
