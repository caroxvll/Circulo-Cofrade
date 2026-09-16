import 'package:flutter/material.dart';

/// Posiciones calibradas sobre `banner_cuentaatras.jpg` (1200 × 240 px).
abstract final class CountdownBannerArtboard {
  static const designWidth = 1200.0;
  static const designHeight = 240.0;

  /// Interior blanco de cada marco (calibrado sobre las casillas del asset).
  static const digitSlots = <Rect>[
    Rect.fromLTWH(660, 21, 70, 106),
    Rect.fromLTWH(775, 21, 70, 106),
    Rect.fromLTWH(890, 21, 70, 106),
  ];

  static List<String> digitsForDays(int days) {
    final clamped = days.clamp(0, 999);
    final text = clamped.toString().padLeft(3, '0');
    return [text[0], text[1], text[2]];
  }
}
