import 'package:cofradeo/features/calendar/utils/holy_week_countdown.dart';
import 'package:cofradeo/core/widgets/countdown_banner_artboard.dart';
import 'package:cofradeo/shared/models/liturgical_countdown_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pascua y Ramos en años conocidos', () {
    expect(easterSunday(2025), DateTime(2025, 4, 20));
    expect(palmSunday(2025), DateTime(2025, 4, 13));

    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(palmSunday(2026), DateTime(2026, 3, 29));
  });

  test('Cuenta atrás visible antes de Ramos', () {
    final countdown = cofradeCountdownFor(DateTime(2026, 3, 1));
    expect(countdown, isNotNull);
    expect(countdown!.headline, contains('Quedan'));
    expect(countdown.subtitle, contains('Domingo de Ramos'));
  });

  test('Domingo de Ramos', () {
    final countdown = cofradeCountdownFor(DateTime(2026, 3, 29));
    expect(countdown?.headline, '¡Hoy es Domingo de Ramos!');
  });

  test('Fuera de temporada no muestra banner', () {
    expect(cofradeCountdownFor(DateTime(2026, 7, 1)), isNull);
  });

  test('Junta puede desactivar el banner', () {
    final settings = LiturgicalCountdownSettings(year: 2026, isEnabled: false);
    expect(cofradeCountdownFor(DateTime(2026, 3, 1), settings: settings), isNull);
  });

  test('Override manual de Ramos', () {
    final settings = LiturgicalCountdownSettings(
      year: 2026,
      palmSundayOverride: DateTime(2026, 4, 5),
      usesManualDates: true,
    );
    final countdown = cofradeCountdownFor(DateTime(2026, 3, 1), settings: settings);
    expect(countdown, isNotNull);
    expect(countdown!.usesManualDates, isTrue);
  });

  test('0 días de antelación: solo desde Domingo de Ramos', () {
    const settings = LiturgicalCountdownSettings(
      year: 2026,
      visibleDaysBefore: 0,
    );
    expect(
      cofradeCountdownFor(DateTime(2026, 3, 28), settings: settings),
      isNull,
    );
    expect(
      cofradeCountdownFor(DateTime(2026, 3, 29), settings: settings)?.headline,
      '¡Hoy es Domingo de Ramos!',
    );
  });

  test('Antelación amplia: visible meses antes de Ramos', () {
    const settings = LiturgicalCountdownSettings(
      year: 2026,
      visibleDaysBefore: 300,
    );
    final countdown = cofradeCountdownFor(DateTime(2025, 6, 27), settings: settings);
    expect(countdown, isNotNull);
    expect(countdown!.headline, contains('Quedan'));
  });

  test('Días desde hoy para activar el banner', () {
    const settings = LiturgicalCountdownSettings(year: 2026);
    final days = countdownVisibleDaysFromToday(DateTime(2025, 6, 27), settings: settings);
    expect(days, greaterThan(200));
    final countdown = cofradeCountdownFor(
      DateTime(2025, 6, 27),
      settings: LiturgicalCountdownSettings(
        year: 2026,
        visibleDaysBefore: days,
      ),
    );
    expect(countdown, isNotNull);
    expect(countdown!.countdownDays, days);
    expect(countdown.usesArtworkBanner, isTrue);
  });

  test('Etiqueta de días del banner entre Faltan y días', () {
    expect(CountdownBannerArtboard.labelForDays(267), '267');
    expect(CountdownBannerArtboard.labelForDays(45), '45');
    expect(CountdownBannerArtboard.labelForDays(5), '5');
  });
}
