import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Medidas compartidas de las pantallas de entrada.
///
/// tight: iPhone SE, Android bajos o letra grande.
/// compact: iPhone 15 y la mayoría de móviles.
/// El resto: Plus, Pro Max y tablets.
class AuthLayoutMetrics {
  const AuthLayoutMetrics({
    required this.height,
    required this.width,
    required this.textScale,
    required this.keyboardOpen,
    required this.tight,
    required this.compact,
    required this.side,
    required this.contentWidth,
    required this.fieldSize,
    required this.titleSize,
    required this.bodySize,
    required this.buttonHeight,
    required this.fieldPad,
  });

  final double height;
  final double width;
  final double textScale;
  final bool keyboardOpen;
  final bool tight;
  final bool compact;
  final double side;
  final double contentWidth;
  final double fieldSize;
  final double titleSize;
  final double bodySize;
  final double buttonHeight;
  final double fieldPad;

  factory AuthLayoutMetrics.of(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final height = constraints.maxHeight;
    final width = constraints.maxWidth;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tight = height < 680 || textScale > 1.25;
    final compact = tight || height < 900;
    final side = width < 360
        ? 16.0
        : width < 420
        ? 20.0
        : 28.0;

    return AuthLayoutMetrics(
      height: height,
      width: width,
      textScale: textScale,
      keyboardOpen: keyboardOpen,
      tight: tight,
      compact: compact,
      side: side,
      contentWidth: (width - side * 2).clamp(0.0, 480.0),
      fieldSize: tight ? 16 : (compact ? 18 : 21),
      titleSize: tight ? 22 : (compact ? 24 : 28),
      bodySize: tight ? 14 : (compact ? 15 : 16),
      buttonHeight: tight ? 44 : (compact ? 48 : 50),
      fieldPad: tight ? 8 : (compact ? 10 : 14),
    );
  }

  /// Hueco bajo la barra cuando el cuerpo pasa por detrás.
  double get belowAppBar => keyboardOpen ? 8 : (tight ? 52 : 64);

  double get bottomPad => tight ? 12 : (compact ? 16 : 24);

  double get linkSize => tight ? 15 : (compact ? 16.5 : 18);
}

double authAppBarTitleSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 360) return 16;
  if (width < 400) return 18;
  return 22;
}

InputDecoration authDarkFieldDecoration({
  required String label,
  required double fieldSize,
  required double verticalPadding,
}) {
  final borderRadius = BorderRadius.circular(16);
  final side = const BorderSide(color: AppColors.gold, width: 1.3);
  return InputDecoration(
    labelText: label,
    labelStyle: AppTypography.displaySmall(
      color: AppColors.goldPale,
    ).copyWith(fontSize: fieldSize, height: 1.15),
    floatingLabelStyle: AppTypography.titleLarge(color: AppColors.gold),
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.08),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 20,
      vertical: verticalPadding,
    ),
    border: OutlineInputBorder(borderRadius: borderRadius, borderSide: side),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: side,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.52)),
    ),
  );
}
