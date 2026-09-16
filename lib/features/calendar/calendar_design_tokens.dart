import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// Medidas del calendario (layout compacto).
abstract final class CalendarDesign {
  static const screenPadding = 14.0;

  // Header
  static const headerTitleSize = 28.0;
  static const headerLetterSpacing = 0.4;
  static const headerBottomGap = 10.0;
  static const dateIconSize = 32.0;
  static const dateIconInnerSize = 15.0;
  static const dateLabelSize = 15.0;
  static const dateSubLabelSize = 11.5;
  static const linkFontSize = 12.0;

  // Hero
  static const heroAspectRatio = 2.35;
  static const heroRadius = 16.0;
  static const heroBadgeWidth = 38.0;
  static const heroBadgeRadius = 6.0;
  static const heroTitleSize = 15.0;
  static const heroMetaSize = 10.0;
  static const heroArrowSize = 30.0;
  static const heroArrowIconSize = 16.0;

  // Secciones
  static const sectionTitleSize = 14.0;
  static const sectionGap = 10.0;
  static const blockGap = 8.0;

  // Filtros
  static const chipHeight = 28.0;
  static const chipRadius = 16.0;
  static const chipFontSize = 11.0;
  static const chipHorizontalPadding = 10.0;

  // Buscador
  static const searchHeight = 38.0;
  static const searchRadius = 19.0;

  // Franja semanal (pastillas rectangulares)
  static const weekTileRadius = 8.0;
  static const weekStripTileHeight = 46.0;
  static const weekDayFontSize = 13.0;
  static const weekLabelFontSize = 7.5;
  static const weekCalendarBtnSize = 30.0;
  static const weekStripHeight = 54.0;

  // Tarjetas de evento
  static const eventCardRadius = 12.0;
  static const eventCardPadding = 6.0;
  static const eventCardGap = 8.0;
  static const eventThumbWidth = 84.0;
  static const eventThumbHeight = 62.0;
  static const eventThumbRadius = 8.0;
  static const eventTitleSize = 12.0;
  static const eventMetaSize = 9.5;
  static const eventTimeFontSize = 9.0;
  static const eventBookmarkSize = 16.0;

  static TextStyle sectionTitle({Color? color}) =>
      AppTypography.displaySmall(color: color).copyWith(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );

  static TextStyle eventTitle({Color? color}) =>
      AppTypography.displaySmall(color: color).copyWith(
        fontSize: eventTitleSize,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );
}
