import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../calendar/utils/holy_week_countdown.dart';

const cuaresmaHubModeConfigKey = 'season_cuaresma_mode';
const semanaSantaHubModeConfigKey = 'season_semana_santa_mode';
const semanaSantaManualDayConfigKey = 'season_semana_santa_manual_day';
const defaultSemanaSantaManualDay = 'Domingo de Ramos';

enum SeasonHubMode {
  automatic('auto'),
  open('open'),
  closed('closed');

  const SeasonHubMode(this.dbValue);

  final String dbValue;

  static SeasonHubMode fromDb(String? value) => switch (value?.trim()) {
    'open' => SeasonHubMode.open,
    'closed' => SeasonHubMode.closed,
    _ => SeasonHubMode.automatic,
  };
}

class SeasonHubSettings {
  const SeasonHubSettings({
    this.cuaresma = SeasonHubMode.automatic,
    this.semanaSanta = SeasonHubMode.automatic,
    this.semanaSantaManualDay = defaultSemanaSantaManualDay,
  });

  final SeasonHubMode cuaresma;
  final SeasonHubMode semanaSanta;
  final String semanaSantaManualDay;

  bool isCuaresmaOpen(DateTime now) => switch (cuaresma) {
    SeasonHubMode.open => true,
    SeasonHubMode.closed => false,
    SeasonHubMode.automatic => _isCuaresmaDate(now),
  };

  bool isSemanaSantaOpen({required bool automaticValue}) =>
      switch (semanaSanta) {
        SeasonHubMode.open => true,
        SeasonHubMode.closed => false,
        SeasonHubMode.automatic => automaticValue,
      };

  String? effectiveSemanaSantaDay(String? automaticDay) =>
      switch (semanaSanta) {
        SeasonHubMode.open => semanaSantaManualDay,
        SeasonHubMode.closed => null,
        SeasonHubMode.automatic => automaticDay,
      };
}

bool _isCuaresmaDate(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var palm = palmSunday(today.year);
  final easter = easterSunday(today.year);
  if (today.isAfter(easter)) {
    palm = palmSunday(today.year + 1);
  }
  final ashWednesday = addCalendarDays(palm, -39);
  return !today.isBefore(ashWednesday) && today.isBefore(palm);
}

final seasonHubSettingsProvider = FutureProvider.autoDispose<SeasonHubSettings>((
  ref,
) async {
  final client = SupabaseBootstrap.client;
  if (client == null) return const SeasonHubSettings();

  try {
    final rows = await client
        .from('app_config')
        .select('key, value')
        .inFilter('key', [
          cuaresmaHubModeConfigKey,
          semanaSantaHubModeConfigKey,
          semanaSantaManualDayConfigKey,
        ]);
    final values = <String, String>{
      for (final row in rows)
        if (row['key'] is String && row['value'] is String)
          row['key'] as String: row['value'] as String,
    };
    return SeasonHubSettings(
      cuaresma: SeasonHubMode.fromDb(values[cuaresmaHubModeConfigKey]),
      semanaSanta: SeasonHubMode.fromDb(values[semanaSantaHubModeConfigKey]),
      semanaSantaManualDay:
          values[semanaSantaManualDayConfigKey]?.trim().isNotEmpty == true
          ? values[semanaSantaManualDayConfigKey]!.trim()
          : defaultSemanaSantaManualDay,
    );
  } catch (_) {
    // Instalaciones antiguas sin app_config conservan el comportamiento por fecha.
    return const SeasonHubSettings();
  }
});
