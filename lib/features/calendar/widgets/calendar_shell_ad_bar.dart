import 'package:flutter/material.dart';

import '../../ads/models/sponsored_ad.dart';
import '../../ads/widgets/sponsored_ad_card.dart';
import '../../ads/widgets/sponsored_placement_slot.dart';

/// Banner de calendario anclado en el shell, justo encima de la bottom nav.
///
/// Al volver a Calendario se pide un sorteo nuevo. El anuncio anterior se
/// mantiene y hace crossfade hacia el siguiente (sin saltar el layout).
/// Si [visible] es false (ficha de evento abierta), colapsa sin desmontar
/// el slot para no re-sortear al cerrar.
class CalendarShellAdBar extends StatelessWidget {
  const CalendarShellAdBar({super.key, this.visible = true});

  final bool visible;

  static double heightForWidth(double width) {
    return 1.5 + width / 4.35;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: const SponsoredPlacementSlot(
            placement: AdPlacement.calendar,
            style: SponsoredAdCardStyle.forumsDocked,
            refreshOnMount: true,
          ),
        ),
      ),
    );
  }
}
