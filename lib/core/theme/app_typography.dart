import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static TextStyle displayLarge({Color? color}) => GoogleFonts.cinzel(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.goldDark,
        letterSpacing: 0.5,
      );

  static TextStyle displayMedium({Color? color}) => GoogleFonts.cinzel(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.goldDark,
      );

  static TextStyle displaySmall({Color? color}) => GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.goldDark,
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
