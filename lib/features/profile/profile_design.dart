import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Tokens visuales del perfil.
abstract final class ProfileDesign {
  static const screenPadding = 14.0;
  static const cardGap = 8.0;
  static const cardRadius = 16.0;
  static const heroRadius = 18.0;
  static const sectionGap = 14.0;
  static const headerAvatarSize = 64.0;
  static const headerAvatarRing = 2.0;

  static const headerTitleSize = 28.0;
  static const headerLetterSpacing = 0.4;
  static const identityNameSize = 20.0;
  static const sectionTitleSize = 15.0;

  static TextStyle screenTitle() => AppTypography.screenTitle().copyWith(
        fontSize: headerTitleSize,
        letterSpacing: headerLetterSpacing,
        height: 1,
      );

  /// Alias histórico usado en estados vacíos y secciones.
  static TextStyle compactScreenTitle() => screenTitle();

  static TextStyle sectionTitle() => AppTypography.titleLarge(
        color: AppColors.burgundy,
      ).copyWith(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      );

  static TextStyle identityName() => AppTypography.titleLarge(
        color: AppColors.textPrimary,
      ).copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  static TextStyle identityHandle() => AppTypography.labelSmall(
        color: AppColors.burgundy,
      ).copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      );

  static TextStyle meta() => AppTypography.labelSmall(
        color: AppColors.textMuted,
      ).copyWith(fontSize: 12);

  static TextStyle statValue() => AppTypography.titleLarge(
        color: AppColors.burgundy,
      ).copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1,
      );

  static TextStyle statLabel() => AppTypography.labelSmall(
        color: AppColors.textSecondary,
      ).copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      );

  static TextStyle filterSectionLabel() => AppTypography.labelSmall(
        color: AppColors.goldDark,
      ).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.1,
      );

  static BoxDecoration cardDecoration({bool highlighted = false}) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: highlighted
              ? AppColors.gold.withValues(alpha: 0.4)
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

  static BoxDecoration heroCardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(heroRadius),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration activityPanelDecoration() => BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );

  static ButtonStyle unfollowButtonStyle() => TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: meta().copyWith(fontWeight: FontWeight.w600),
      );
}
