import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      primary: AppColors.burgundy,
      onPrimary: AppColors.textOnDark,
      secondary: AppColors.gold,
      onSecondary: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.goldDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.displaySmall(),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.burgundy),
      textTheme: TextTheme(
        displayLarge: _plain(AppTypography.displayLarge()),
        displayMedium: _plain(AppTypography.displayMedium()),
        displaySmall: _plain(AppTypography.displaySmall()),
        titleLarge: _plain(AppTypography.titleLarge()),
        bodyLarge: _plain(AppTypography.bodyLarge()),
        bodyMedium: _plain(AppTypography.bodyMedium()),
        labelSmall: _plain(AppTypography.labelSmall()),
      ),
    );
  }

  static TextStyle _plain(TextStyle style) =>
      style.copyWith(decoration: TextDecoration.none);
}
