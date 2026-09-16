import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Tokens visuales de la pantalla Buscar (alineados con calendario).
abstract final class SearchDesign {
  static const screenPadding = 14.0;
  static const sectionGap = 14.0;
  static const cardGap = 8.0;
  static const cardRadius = 16.0;

  static const headerTitleSize = 28.0;
  static const headerLetterSpacing = 0.4;
  static const sectionTitleSize = 14.0;

  static const searchHeight = 40.0;
  static const searchRadius = 14.0;

  static TextStyle screenTitle() => AppTypography.screenTitle().copyWith(
        fontSize: headerTitleSize,
        letterSpacing: headerLetterSpacing,
        height: 1,
      );

  static BoxDecoration cardDecoration({bool highlighted = false}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: highlighted
              ? AppColors.gold.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static TextStyle sectionTitle() => AppTypography.titleLarge(
        color: AppColors.burgundy,
      ).copyWith(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      );

  static TextStyle sectionMeta() => AppTypography.labelSmall(
        color: AppColors.textMuted,
      ).copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      );

  static TextStyle resultsSummary() => AppTypography.labelSmall(
        color: AppColors.textSecondary,
      ).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
      );
}
