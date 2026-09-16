import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Inter, 11px: tipografía unificada del detalle de foro y tarjetas de tema.
abstract final class ForumTopicsTypography {
  static const fontSize = 11.0;
  static const lineHeight = 1.2;
  static const compactLineHeight = 1.0;
  static const letterSpacing = 0.1;

  static const compactTextHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  static TextStyle style({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
    double? height,
  }) =>
      AppTypography.labelSmall(color: color).copyWith(
        fontSize: fontSize,
        height: height ?? lineHeight,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      );

  /// Texto apretado dentro de tarjetas de tema.
  static TextStyle card({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      style(
        color: color,
        fontWeight: fontWeight,
        height: compactLineHeight,
      );

  static TextStyle onDark({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      style(
        color: color ?? Colors.white.withValues(alpha: 0.9),
        fontWeight: fontWeight,
      );

  static TextStyle heroTitle({Color color = AppColors.gold}) =>
      style(color: color, fontWeight: FontWeight.w700);

  static TextStyle sectionLabel({Color? color}) => style(
        color: color ?? AppColors.goldDark,
        fontWeight: FontWeight.w700,
      );
}
