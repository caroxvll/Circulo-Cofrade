import 'package:flutter/material.dart';

/// Posiciones calibradas sobre `bannerDias.png` (1200 × 276 px).
abstract final class CountdownBannerArtboard {
  static const designWidth = 1200.0;
  static const designHeight = 276.0;

  /// Hueco entre «Faltan» y «días» en la primera línea del arte.
  static const daysSlot = Rect.fromLTWH(378, 52, 160, 72);

  static String labelForDays(int days) => days.clamp(0, 999).toString();
}
