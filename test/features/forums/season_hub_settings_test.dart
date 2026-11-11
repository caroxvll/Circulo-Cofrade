import 'package:cofradeo/features/forums/season_hub_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeasonHubSettings', () {
    test('abre Cuaresma automáticamente entre Ceniza y Ramos', () {
      const settings = SeasonHubSettings();

      expect(settings.isCuaresmaOpen(DateTime(2027, 2, 9)), isFalse);
      expect(settings.isCuaresmaOpen(DateTime(2027, 2, 10)), isTrue);
      expect(settings.isCuaresmaOpen(DateTime(2027, 3, 20)), isTrue);
      expect(settings.isCuaresmaOpen(DateTime(2027, 3, 21)), isFalse);
    });

    test('respeta la apertura y el cierre manuales', () {
      const open = SeasonHubSettings(
        cuaresma: SeasonHubMode.open,
        semanaSanta: SeasonHubMode.open,
        semanaSantaManualDay: 'Martes Santo',
      );
      const closed = SeasonHubSettings(
        cuaresma: SeasonHubMode.closed,
        semanaSanta: SeasonHubMode.closed,
      );

      expect(open.isCuaresmaOpen(DateTime(2026, 11, 10)), isTrue);
      expect(open.isSemanaSantaOpen(automaticValue: false), isTrue);
      expect(open.effectiveSemanaSantaDay('Jueves Santo'), 'Martes Santo');
      expect(closed.isCuaresmaOpen(DateTime(2027, 2, 20)), isFalse);
      expect(closed.isSemanaSantaOpen(automaticValue: true), isFalse);
      expect(closed.effectiveSemanaSantaDay('Jueves Santo'), isNull);
    });

    test('en automático conserva la jornada real', () {
      const settings = SeasonHubSettings();

      expect(
        settings.effectiveSemanaSantaDay('Miércoles Santo'),
        'Miércoles Santo',
      );
    });
  });
}
