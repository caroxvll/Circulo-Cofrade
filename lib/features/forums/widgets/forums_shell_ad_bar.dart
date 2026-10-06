import 'package:flutter/material.dart';

import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';

/// Banner de foros anclado en el shell, justo encima de la bottom nav.
///
/// Al volver a Foros se pide un sorteo nuevo. El anuncio anterior se mantiene
/// y hace crossfade hacia el siguiente (sin vaciar la barra ni saltar layout).
class ForumsShellAdBar extends StatelessWidget {
  const ForumsShellAdBar({super.key});

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  @override
  Widget build(BuildContext context) {
    return const SponsoredPlacementSlot(
      placement: AdPlacement.forumsTop,
      style: SponsoredAdCardStyle.forumsDocked,
      refreshOnMount: true,
    );
  }
}
