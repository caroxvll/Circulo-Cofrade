import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Contenido (fondo blanco-beige) ──────────────────────────────────────
  static const background = Color(0xFFF9F6F1);
  static const backgroundElevated = Color(0xFFF1EAE2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF5EFE8);
  static const border = Color(0xFFE7DFD6);

  // ── Barra inferior ────────────────────────────────────────────────────────
  static const navBarBackground = Color(0xFFFFFFFF);

  // ── Acentos de marca ──────────────────────────────────────────────────────
  static const gold = Color(0xFFCFA74A);
  static const goldDark = Color(0xFF9B7424);
  static const goldLight = Color(0xFFD4C4A8);
  static const goldPale = Color(0xFFE5D1B8);

  static const burgundy = Color(0xFF7A0814);
  static const burgundyDark = Color(0xFF4D0008);

  static const brandPurple = Color(0xFF4A148C);

  // ── Texto sobre fondo claro ─────────────────────────────────────────────
  static const textPrimary = Color(0xFF241F1C);
  static const textSecondary = Color(0xFF6E6A67);
  static const textMuted = Color(0xFF9A9288);

  // ── Texto sobre fondos oscuros (nav, badges, hero foros) ─────────────────
  static const textOnDark = Color(0xFFFFFFFF);
  static const heroIconOnDark = Color(0xFFF5EFE8);

  static const accentRed = Color(0xFFC44B4B);
  static const notificationDot = Color(0xFFE53935);

  static const chipSelected = Color(0xFFE5D1B8);
  static const chipSelectedText = Color(0xFF2C2417);

  static const navInactive = Color(0xFFCBBCA9);
}
