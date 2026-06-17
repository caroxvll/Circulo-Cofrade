import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Contenido (fondo blanco-beige) ──────────────────────────────────────
  static const background = Color(0xFFFAF7F2);
  static const backgroundElevated = Color(0xFFF3EDE4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF5F0E8);
  static const border = Color(0xFFE8DFD0);

  // ── Barra inferior (oscura, sin cambios) ──────────────────────────────────
  static const navBarBackground = Color(0xFF000000);

  // ── Acentos de marca ──────────────────────────────────────────────────────
  static const gold = Color(0xFFD4AF37);
  static const goldDark = Color(0xFF8B6914);
  static const goldLight = Color(0xFFD4C4A8);
  static const goldPale = Color(0xFFE5D1B8);

  static const burgundy = Color(0xFF7A1111);
  static const burgundyDark = Color(0xFF5C0D0D);

  static const brandPurple = Color(0xFF4A148C);

  // ── Texto sobre fondo claro ─────────────────────────────────────────────
  static const textPrimary = Color(0xFF2C2417);
  static const textSecondary = Color(0xFF6B635A);
  static const textMuted = Color(0xFF9A9288);

  // ── Texto sobre fondos oscuros (nav, badges) ──────────────────────────────
  static const textOnDark = Color(0xFFFFFFFF);

  static const accentRed = Color(0xFFC44B4B);
  static const notificationDot = Color(0xFFE53935);

  static const chipSelected = Color(0xFFE5D1B8);
  static const chipSelectedText = Color(0xFF2C2417);

  static const navInactive = Color(0xFF9A8B7A);
}
