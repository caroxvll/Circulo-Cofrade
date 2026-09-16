import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/text_normalize.dart';

/// Texto plantilla generado al crear tablones de hermandad.
bool isHermandadBoardTemplateBody(String body) {
  final text = body.trim();
  if (text.isEmpty) return false;
  return text.contains('Este es el espacio de seguimiento') &&
      text.contains('información oficial');
}

/// Cuerpo editable del tablón; `null` si sigue siendo la plantilla.
String? hermandadBoardCustomBody(String body) {
  if (isHermandadBoardTemplateBody(body)) return null;
  final text = normalizeStoredText(body).trim();
  return text.isEmpty ? null : text;
}

/// `"Domingo de Ramos · La Borriquita"` → `(Domingo de Ramos, La Borriquita)`.
({String? processionDay, String hermandadName}) parseHermandadTopicTitle(
  String title,
) {
  final parts = title.split(' · ').map((p) => p.trim()).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.length >= 2) {
    return (processionDay: list.first, hermandadName: list.sublist(1).join(' · '));
  }
  return (processionDay: null, hermandadName: title.trim());
}

/// Franja de color del card según el día de estación.
Color hermandadDayAccentColor(String? day) {
  return switch (day) {
    'Viernes de Dolores' => const Color(0xFF2E7D32),
    'Sábado de Pasión' => const Color(0xFF6A1B9A),
    'Domingo de Ramos' => AppColors.burgundy,
    'Lunes Santo' => const Color(0xFF1565C0),
    'Martes Santo' => const Color(0xFF5D4037),
    'Miércoles Santo' => const Color(0xFF00695C),
    'Jueves Santo' => const Color(0xFF4527A0),
    'Madrugá' => const Color(0xFF212121),
    'Viernes Santo' => const Color(0xFFB71C1C),
    'Sábado Santo' => const Color(0xFF37474F),
    'Domingo de Resurrección' => AppColors.goldDark,
    _ => AppColors.burgundy,
  };
}

/// Etiqueta corta estilo calendario: (`Vie`, `Dolores`).
({String weekday, String label}) hermandadDayChipParts(String day) {
  return switch (day) {
    'Viernes de Dolores' => (weekday: 'Vie', label: 'Dolores'),
    'Sábado de Pasión' => (weekday: 'Sáb', label: 'Pasión'),
    'Domingo de Ramos' => (weekday: 'Dom', label: 'Ramos'),
    'Lunes Santo' => (weekday: 'Lun', label: 'Santo'),
    'Martes Santo' => (weekday: 'Mar', label: 'Santo'),
    'Miércoles Santo' => (weekday: 'Mié', label: 'Santo'),
    'Jueves Santo' => (weekday: 'Jue', label: 'Santo'),
    'Madrugá' => (weekday: 'Vie', label: 'Madrugá'),
    'Viernes Santo' => (weekday: 'Vie', label: 'Santo'),
    'Sábado Santo' => (weekday: 'Sáb', label: 'Santo'),
    'Domingo de Resurrección' => (weekday: 'Dom', label: 'Resurrección'),
    _ => (
        weekday: day.split(' ').first,
        label: day.split(' ').skip(1).join(' '),
      ),
  };
}

/// Offset en días respecto al Domingo de Resurrección.
int hermandadStationOffsetFromEaster(String day) {
  return switch (day) {
    'Viernes de Dolores' => -9,
    'Sábado de Pasión' => -8,
    'Domingo de Ramos' => -7,
    'Lunes Santo' => -6,
    'Martes Santo' => -5,
    'Miércoles Santo' => -4,
    'Jueves Santo' => -3,
    'Madrugá' => -2,
    'Viernes Santo' => -2,
    'Sábado Santo' => -1,
    'Domingo de Resurrección' => 0,
    _ => 0,
  };
}

/// Fecha civil del día de estación (Madrugá y Viernes Santo comparten día).
DateTime hermandadStationDate(String day, DateTime easterSunday) {
  final e = DateTime(easterSunday.year, easterSunday.month, easterSunday.day);
  return DateTime(
    e.year,
    e.month,
    e.day + hermandadStationOffsetFromEaster(day),
  );
}

/// Formato corto tipo mock: `11 abr`.
String formatHermandadStationDateShort(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
