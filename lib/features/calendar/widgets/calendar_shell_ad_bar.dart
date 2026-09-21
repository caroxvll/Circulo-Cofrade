import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ads_provider.dart';
import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';

/// Banner de calendario anclado en el shell, justo encima de la bottom nav.
///
/// Al volver a Calendario se pide un sorteo nuevo. El anuncio anterior se
/// mantiene visible hasta que llega el siguiente (sin saltar el layout).
class CalendarShellAdBar extends ConsumerStatefulWidget {
  const CalendarShellAdBar({super.key});

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  static const query = AdPlacementQuery(placement: AdPlacement.calendar);

  @override
  ConsumerState<CalendarShellAdBar> createState() => _CalendarShellAdBarState();
}

class _CalendarShellAdBarState extends ConsumerState<CalendarShellAdBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adForPlacementProvider(CalendarShellAdBar.query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final adAsync =
        ref.watch(adForPlacementProvider(CalendarShellAdBar.query));
    final placeholder = SizedBox(
      height:
          CalendarShellAdBar.heightForWidth(MediaQuery.sizeOf(context).width),
    );

    return adAsync.when(
      skipLoadingOnReload: true,
      data: (ad) {
        if (ad == null) return const SizedBox.shrink();
        return SponsoredAdCard(
          ad: ad,
          style: SponsoredAdCardStyle.forumsDocked,
        );
      },
      loading: () => placeholder,
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
