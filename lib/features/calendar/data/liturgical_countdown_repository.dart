import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/liturgical_countdown_settings.dart';

class LiturgicalCountdownRepository {
  LiturgicalCountdownRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<LiturgicalCountdownSettings?> fetchForYear(int year) async {
    if (_client == null) return null;

    final row = await _client!
        .from('liturgical_countdown_settings')
        .select()
        .eq('year', year)
        .maybeSingle();

    if (row == null) return null;
    return _fromRow(row);
  }

  Future<void> upsert(LiturgicalCountdownSettings settings) async {
    if (_client == null) throw const LiturgicalCountdownUnavailableException();

    await _client!.from('liturgical_countdown_settings').upsert({
      'year': settings.year,
      'palm_sunday_date': settings.palmSundayOverride != null
          ? _dateOnly(settings.palmSundayOverride!).toIso8601String().split('T').first
          : null,
      'easter_sunday_date': settings.easterSundayOverride != null
          ? _dateOnly(settings.easterSundayOverride!)
              .toIso8601String()
              .split('T')
              .first
          : null,
      'visible_days_before': settings.visibleDaysBefore,
      'is_enabled': settings.isEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> clearOverrides(int year) async {
    if (_client == null) throw const LiturgicalCountdownUnavailableException();

    await _client!
        .from('liturgical_countdown_settings')
        .update({
          'palm_sunday_date': null,
          'easter_sunday_date': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('year', year);
  }

  LiturgicalCountdownSettings _fromRow(Map<String, dynamic> row) {
    final palmRaw = row['palm_sunday_date'] as String?;
    final easterRaw = row['easter_sunday_date'] as String?;

    return LiturgicalCountdownSettings(
      year: row['year'] as int,
      palmSundayOverride:
          palmRaw == null ? null : DateTime.parse(palmRaw),
      easterSundayOverride:
          easterRaw == null ? null : DateTime.parse(easterRaw),
      visibleDaysBefore: row['visible_days_before'] as int? ?? 60,
      isEnabled: row['is_enabled'] as bool? ?? true,
      usesManualDates: palmRaw != null || easterRaw != null,
    );
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class LiturgicalCountdownUnavailableException implements Exception {
  const LiturgicalCountdownUnavailableException();
}

LiturgicalCountdownRepository createLiturgicalCountdownRepository() {
  return LiturgicalCountdownRepository(client: SupabaseBootstrap.client);
}
