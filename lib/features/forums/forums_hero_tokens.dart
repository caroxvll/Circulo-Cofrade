import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

import 'forum_topics_typography.dart';

/// Métricas compartidas del hero de foros (lista y detalle de pilar).
abstract final class ForumsHeroTokens {
  static const horizontalPadding = 20.0;
  static const bottomPadding = 8.0;
  static const topExtraPadding = 4.0;
  /// Detalle de foro: sin aire extra bajo la status bar (la flecha no queda flotando).
  static const detailTopExtraPadding = 0.0;
  static const afterToolbarGap = 4.0;
  static const afterTitleGap = 4.0;

  /// Cuánto sube el panel blanco sobre el hero.
  static const panelOverlapReserve = 26.0;

  /// Aire entre la última línea del hero y donde empieza el solape.
  static const panelOverlapClearance = 14.0;
  static const panelTopRadius = 24.0;

  /// Padding inferior del hero: zona que el panel blanco puede cubrir sin
  /// tapar título, stats ni badge.
  static double get detailHeroBottomPadding =>
      panelOverlapReserve + panelOverlapClearance;

  static EdgeInsets contentPadding(BuildContext context) => EdgeInsets.fromLTRB(
        horizontalPadding,
        MediaQuery.paddingOf(context).top + topExtraPadding,
        horizontalPadding,
        bottomPadding,
      );

  static EdgeInsets detailHeroPadding(BuildContext context) {
    // Solo lo mínimo de la status bar; el contenido empieza ya junto a ella.
    final statusTop = MediaQuery.viewPaddingOf(context).top;
    return EdgeInsets.fromLTRB(
      8,
      statusTop > 0 ? statusTop : 8,
      16,
      detailHeroBottomPadding,
    );
  }

  static LinearGradient gradientOverlay() => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.58),
          Colors.black.withValues(alpha: 0.82),
        ],
        stops: const [0.0, 0.52, 1.0],
      );

  /// Subtítulo blanco bajo el título principal del hero.
  static TextStyle heroSubtitleStyle() =>
      AppTypography.displaySmall(color: Colors.white).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.15,
      );

  /// Título «FOROS» del listado (un poco más contenido que el screenTitle global).
  static TextStyle heroTitleStyle() =>
      AppTypography.screenTitle(color: AppColors.gold).copyWith(
        fontSize: 28,
        height: 1.05,
        letterSpacing: 0.6,
      );

  /// Descripción del foro en el hero de detalle.
  static TextStyle detailHeroDescriptionStyle() =>
      ForumTopicsTypography.onDark(fontWeight: FontWeight.w400);
}
