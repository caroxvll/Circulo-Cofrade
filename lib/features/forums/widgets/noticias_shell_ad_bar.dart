import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ads_provider.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';

/// Banner de Noticias anclado encima de la bottom nav (mismo formato que Foros).
class NoticiasShellAdBar extends ConsumerWidget {
  const NoticiasShellAdBar({super.key});

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAsync = ref.watch(
      adForPlacementProvider(
        const AdPlacementQuery(placement: AdPlacement.noticias),
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
