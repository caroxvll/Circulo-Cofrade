import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../utils/cofrade_gamification.dart';
import 'cofrade_rank_label.dart';

/// Rango cofrade visible bajo el @handle. Sin puntos ni pistas de progreso.
class AuthorCofradeRankLine extends StatelessWidget {
  const AuthorCofradeRankLine({
    super.key,
    required this.trophyPoints,
    this.compact = false,
    this.emphasized = false,
  });

  final int trophyPoints;
  final bool compact;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final title = cofradeRankTitleForPoints(trophyPoints);
    if (title.trim().isEmpty) return const SizedBox.shrink();

    if (emphasized) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTypography.rankTitle(
          color: AppColors.burgundy,
        ).copyWith(fontSize: compact ? 12 : 13),
      );
    }

    return CofradeRankLabel(
      title: title,
      compact: compact,
    );
  }
}
