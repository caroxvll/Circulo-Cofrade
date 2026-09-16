import '../../../shared/models/liturgical_countdown_settings.dart';

/// Fechas litúrgicas y textos para la cuenta atrás cofrade.
///
/// ## Cálculo automático (sin datos en Junta)
///
/// 1. **Domingo de Pascua** — algoritmo gregoriano (Meeus / Anonymous Gregorian):
///    usa el ciclo metónico de 19 años, el siglo y correcciones para ubicar el
///    domingo de Resurrección en el calendario civil.
/// 2. **Domingo de Ramos** — siempre **7 días antes** de Pascua (entrada triunfal).
///
/// En España y la Iglesia católica occidental coincide con el calendario oficial.
/// La Junta puede **sobreescribir** fechas en Supabase si hiciera falta.
class CofradeCountdown {
  const CofradeCountdown({
    required this.targetDate,
    required this.headline,
    this.subtitle,
    this.milestone = CofradeCountdownMilestone.palmSunday,
    this.usesManualDates = false,
    this.countdownDays,
  });

  final DateTime targetDate;
  final String headline;
  final String? subtitle;
  final CofradeCountdownMilestone milestone;
  final bool usesManualDates;

  /// Días restantes para el hito del banner con cifras (p. ej. 267 → 2·6·7).
  final int? countdownDays;

  bool get usesArtworkBanner =>
      milestone == CofradeCountdownMilestone.palmSunday && countdownDays != null;
}

enum CofradeCountdownMilestone { palmSunday, holyWeek, easter }

/// Días antes de Ramos por defecto si la Junta no indica otro valor.
const defaultCountdownVisibleDaysBeforePalmSunday = 60;

/// Máximo configurable desde Junta (cubre más de un año natural).
const maxCountdownVisibleDaysBeforePalmSunday = 400;

/// Domingo de Pascua — algoritmo gregoriano (Anonymous Gregorian / Meeus).
///
/// Pasos resumidos:
/// - `a` = año mod 19 (posición en el ciclo metónico lunar).
/// - `b`, `c` = siglo y año dentro del siglo.
/// - Correcciones `d`…`m` ajustan la luna y el día de la semana.
/// - Resultado: mes y día del domingo de Resurrección.
DateTime easterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Suma días en calendario civil (sin saltos por DST).
DateTime addCalendarDays(DateTime date, int days) {
  final d = DateTime(date.year, date.month, date.day);
  return DateTime(d.year, d.month, d.day + days);
}

/// Domingo de Ramos = Domingo de Pascua − 7 días.
DateTime palmSunday(int year) => addCalendarDays(easterSunday(year), -7);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime from, DateTime to) {
  return _dateOnly(to).difference(_dateOnly(from)).inDays;
}

DateTime _resolvePalmSunday(int year, LiturgicalCountdownSettings? settings) {
  final override = settings?.palmSundayOverride;
  if (override != null) return _dateOnly(override);
  return _dateOnly(palmSunday(year));
}

DateTime _resolveEasterSunday(int year, LiturgicalCountdownSettings? settings) {
  final override = settings?.easterSundayOverride;
  if (override != null) return _dateOnly(override);
  final palm = settings?.palmSundayOverride;
  if (palm != null) return addCalendarDays(_dateOnly(palm), 7);
  return _dateOnly(easterSunday(year));
}

/// `null` si estamos fuera de la ventana visible o la Junta lo desactivó.
CofradeCountdown? cofradeCountdownFor(
  DateTime reference, {
  LiturgicalCountdownSettings? settings,
}) {
  if (settings != null && !settings.isEnabled) return null;

  final today = _dateOnly(reference);
  final year = today.year;
  final visibleDays = settings?.visibleDaysBefore ??
      defaultCountdownVisibleDaysBeforePalmSunday;
  final manual = settings?.usesManualDates ?? false;

  var palm = _resolvePalmSunday(year, settings);
  var easter = _resolveEasterSunday(year, settings);

  if (today.isAfter(_dateOnly(easter))) {
    final nextYear = year + 1;
    final nextSettings = settings?.year == nextYear ? settings : null;
    palm = _resolvePalmSunday(nextYear, nextSettings);
    easter = _resolveEasterSunday(nextYear, nextSettings);
  }

  final palmDay = _dateOnly(palm);
  final easterDay = _dateOnly(easter);
  final holySaturday = addCalendarDays(easterDay, -1);
  final windowStart = addCalendarDays(palmDay, -visibleDays);

  if (today.isBefore(windowStart) || today.isAfter(holySaturday)) {
    return null;
  }

  final daysToPalm = _daysBetween(today, palmDay);

  if (daysToPalm > 1) {
    return CofradeCountdown(
      targetDate: palmDay,
      headline: 'Quedan $daysToPalm días',
      subtitle: 'para el Domingo de Ramos',
      countdownDays: daysToPalm,
      usesManualDates: manual,
    );
  }

  if (daysToPalm == 1) {
    return CofradeCountdown(
      targetDate: palmDay,
      headline: 'Mañana es Domingo de Ramos',
      countdownDays: 1,
      usesManualDates: manual,
    );
  }

  if (today == palmDay) {
    return CofradeCountdown(
      targetDate: palmDay,
      headline: '¡Hoy es Domingo de Ramos!',
      subtitle: 'Comienza la Semana Santa',
      countdownDays: 0,
      usesManualDates: manual,
    );
  }

  if (today.isBefore(easterDay)) {
    final daysToEaster = _daysBetween(today, easterDay);
    return CofradeCountdown(
      targetDate: easterDay,
      headline: 'Semana Santa en curso',
      subtitle: daysToEaster == 1
          ? 'Mañana es Domingo de Resurrección'
          : 'Faltan $daysToEaster días para el Domingo de Resurrección',
      milestone: CofradeCountdownMilestone.holyWeek,
      usesManualDates: manual,
    );
  }

  return null;
}

/// Días de antelación para que el banner sea visible [reference] (p. ej. hoy).
int countdownVisibleDaysFromToday(
  DateTime reference, {
  LiturgicalCountdownSettings? settings,
}) {
  final today = _dateOnly(reference);
  final year = today.year;

  var palm = _resolvePalmSunday(year, settings);
  final easter = _resolveEasterSunday(year, settings);

  if (today.isAfter(_dateOnly(easter))) {
    final nextYear = year + 1;
    final nextSettings = settings?.year == nextYear ? settings : null;
    palm = _resolvePalmSunday(nextYear, nextSettings);
  }

  final days = _daysBetween(today, _dateOnly(palm));
  return days < 0 ? 0 : days;
}

/// Fechas calculadas automáticamente para un año (vista previa en Junta).
({DateTime palmSunday, DateTime easterSunday}) computedLiturgicalDates(int year) {
  final easter = _dateOnly(easterSunday(year));
  return (palmSunday: addCalendarDays(easter, -7), easterSunday: easter);
}
