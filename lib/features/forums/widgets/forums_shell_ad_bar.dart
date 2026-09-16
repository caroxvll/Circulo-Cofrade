import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ads_provider.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';

/// Banner de foros anclado en el shell, justo encima de la bottom nav.
class ForumsShellAdBar extends ConsumerWidget {
  const ForumsShellAdBar({super.key});

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAsync = ref.watch(
      adForPlacementProvider(
        const AdPlacementQuery(placement: AdPlacement.forumsTop),
      ),
    );

    return adAsync.when(
      data: (ad) {
        if (ad == null) return const SizedBox.shrink();
        return SponsoredAdCard(
          ad: ad,
          style: SponsoredAdCardStyle.forumsDocked,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
