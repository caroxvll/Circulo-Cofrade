import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'forum_topics_typography.dart';

/// Escala compacta y legible para el interior del hilo.
abstract final class TopicDetailTypography {
  static const titleSize = 16.0;
  static const heroTitleSize = 18.0;
  static const bodySize = 13.0;
  static const metaSize = 11.0;

  static TextStyle title({Color? color}) => AppTypography.titleLarge(
        color: color ?? AppColors.textPrimary,
      ).copyWith(
        fontSize: titleSize,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      );

  static TextStyle heroTitle({Color? color}) => title(color: color).copyWith(
        fontSize: heroTitleSize,
        height: 1.3,
        letterSpacing: 0.1,
      );

  static TextStyle body({Color? color}) => AppTypography.bodyMedium(
        color: color ?? AppColors.textPrimary,
      ).copyWith(
        fontSize: bodySize,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  static TextStyle meta({Color? color, FontWeight? fontWeight}) =>
      ForumTopicsTypography.style(
        color: color ?? AppColors.textMuted,
        fontWeight: fontWeight ?? FontWeight.w500,
      );

  static TextStyle authorHandle({bool tappable = true}) =>
      ForumTopicsTypography.style(
        color: tappable ? AppColors.burgundy : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      );

  static TextStyle sectionTitle() => ForumTopicsTypography.style(
        color: AppColors.burgundyDark,
        fontWeight: FontWeight.w700,
      ).copyWith(letterSpacing: 0.35);

  static TextStyle sectionSubtitle() => meta(color: AppColors.textMuted);

  static TextStyle appBarTitle() => ForumTopicsTypography.style(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ).copyWith(fontSize: 13);

  /// Título editorial del AppBar (detalle de tema / noticia).
  static TextStyle editorialAppBarTitle() => AppTypography.displaySmall(
        color: AppColors.burgundyDark,
      ).copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.05,
      );

  /// Kicker en mayúsculas bajo el nombre del foro.
  static TextStyle editorialAppBarKicker() => meta(
        color: AppColors.textMuted,
      ).copyWith(
        fontSize: 9,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );
}
