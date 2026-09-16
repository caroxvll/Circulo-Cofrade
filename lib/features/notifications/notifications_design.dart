import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Tokens visuales de la bandeja de notificaciones.
abstract final class NotificationsDesign {
  static const screenPadding = 14.0;
  static const cardGap = 8.0;
  static const cardRadius = 16.0;

  static const headerTitleSize = 28.0;
  static const headerLetterSpacing = 0.4;

  static TextStyle screenTitle() => AppTypography.screenTitle().copyWith(
        fontSize: headerTitleSize,
        letterSpacing: headerLetterSpacing,
        height: 1,
      );

  /// Alias histórico usado en tarjetas secundarias.
  static TextStyle compactScreenTitle() => screenTitle();

  static TextStyle actionLabel() => AppTypography.labelSmall(
        color: AppColors.burgundy,
      ).copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      );

  static TextStyle meta() => AppTypography.labelSmall(
        color: AppColors.textMuted,
      ).copyWith(fontSize: 12);

  static BoxDecoration settingsCardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );

  static TextStyle sectionTitle() => AppTypography.titleLarge().copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle sectionHint() => AppTypography.bodyMedium(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 13, height: 1.4);

  static TextStyle prefTitle() => AppTypography.titleLarge().copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle prefSubtitle() => AppTypography.bodyMedium(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 12, height: 1.35);

  static BoxDecoration cardDecoration({required bool unread}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: unread
              ? AppColors.burgundy.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );
}
