import 'package:flutter/material.dart';

import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';

/// Banner de calendario anclado en el shell, justo encima de la bottom nav.
///
/// Al volver a Calendario se pide un sorteo nuevo. El anuncio anterior se
/// mantiene y hace crossfade hacia el siguiente (sin saltar el layout).
class CalendarShellAdBar extends StatelessWidget {
  const CalendarShellAdBar({super.key});

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  @override
  Widget build(BuildContext context) {
    return const SponsoredPlacementSlot(
      placement: AdPlacement.calendar,
      style: SponsoredAdCardStyle.forumsDocked,
      refreshOnMount: true,
    );
  }
}
