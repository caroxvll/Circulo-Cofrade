import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/ads_repository.dart';
import 'models/sponsored_ad.dart';

export 'data/ads_repository.dart' show AdStatisticsRow;

@immutable
class AdPlacementQuery {
  const AdPlacementQuery({
    required this.placement,
    this.forumId,
    this.topicId,
  });

  final AdPlacement placement;
  final String? forumId;
  final String? topicId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdPlacementQuery &&
            other.placement == placement &&
            other.forumId == forumId &&
            other.topicId == topicId;
  }

  @override
  int get hashCode => Object.hash(placement, forumId, topicId);
}

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return createAdsRepository();
});

final adForPlacementProvider =
    FutureProvider.autoDispose.family<SponsoredAd?, AdPlacementQuery>(
  (ref, query) {
    // Calendario / Foros: no desechar al cambiar de pestaña (evita salto de layout).
    if (query.placement == AdPlacement.forumsTop ||
        query.placement == AdPlacement.calendar) {
      ref.keepAlive();
    }
    return ref.watch(adsRepositoryProvider).fetchAd(
          query.placement,
          forumId: query.forumId,
          topicId: query.topicId,
        );
  },
);

final adminAdsProvider = FutureProvider<List<SponsoredAd>>((ref) {
  return ref.watch(adsRepositoryProvider).fetchAdminAds();
});

/// Rango del informe: [from] inclusive, [to] exclusive. Null = sin límite.
typedef AdStatsRange = ({DateTime? from, DateTime? to});

final adminAdStatisticsProvider =
    FutureProvider.family<List<AdStatisticsRow>, AdStatsRange>((ref, range) {
  return ref.watch(adsRepositoryProvider).fetchAdStatistics(
        from: range.from,
        to: range.to,
      );
});

void invalidateForumAds(WidgetRef ref) {
  ref.invalidate(adForPlacementProvider);
}

void invalidateAdminAdStatistics(WidgetRef ref) {
  ref.invalidate(adminAdStatisticsProvider);
}
