import 'package:flutter/material.dart';

import '../utils/cofrade_gamification.dart';
import 'cofrade_rank_label.dart';

/// Rango cofrade visible bajo el @handle. Sin puntos ni pistas de progreso.
class AuthorCofradeRankLine extends StatelessWidget {
  const AuthorCofradeRankLine({
    super.key,
    required this.trophyPoints,
    this.compact = false,
  });

  final int trophyPoints;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CofradeRankLabel(
      title: cofradeRankTitleForPoints(trophyPoints),
      compact: compact,
    );
  }
}
