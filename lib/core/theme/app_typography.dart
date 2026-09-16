import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const screenTitleFontSize = 34.0;
  static const screenTitleLetterSpacing = 0.5;
  static const screenAppBarTitleFontSize = 26.0;

  static TextStyle displayLarge({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 42,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1,
      );

  /// Título de pestaña principal (p. ej. CALENDARIO, BUSCAR).
  static TextStyle screenTitle({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: screenTitleFontSize,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.goldDark,
        height: 1,
        letterSpacing: screenTitleLetterSpacing,
      );

  /// Título en AppBar de pantallas secundarias.
  static TextStyle screenAppBarTitle({Color? color}) =>
      screenTitle(color: color).copyWith(fontSize: screenAppBarTitleFontSize);

  static TextStyle displayMedium({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.05,
      );

  static TextStyle displaySmall({Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.08,
      );

  static TextStyle titleLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color ?? AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle labelSmall({Color? color}) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: color ?? AppColors.textMuted,
    letterSpacing: 0.2,
  );
}
