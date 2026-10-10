import 'package:flutter/material.dart';

import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';

/// Banner de Noticias anclado encima de la bottom nav (mismo formato que Foros).
class NoticiasShellAdBar extends StatelessWidget {
  const NoticiasShellAdBar({super.key});

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  @override
  Widget build(BuildContext context) {
    return const SponsoredPlacementSlot(
      placement: AdPlacement.noticias,
      style: SponsoredAdCardStyle.forumsDocked,
      refreshOnMount: true,
    );
  }
}
