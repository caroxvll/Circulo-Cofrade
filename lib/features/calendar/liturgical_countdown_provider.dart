import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/models/liturgical_countdown_settings.dart';
import 'data/liturgical_countdown_repository.dart';
import 'utils/holy_week_countdown.dart';

final liturgicalCountdownRepositoryProvider =
    Provider<LiturgicalCountdownRepository>((ref) {
  return createLiturgicalCountdownRepository();
});

final liturgicalCountdownSettingsProvider =
    FutureProvider.autoDispose.family<LiturgicalCountdownSettings, int>(
  (ref, year) async {
    final remote = await ref
        .watch(liturgicalCountdownRepositoryProvider)
        .fetchForYear(year);
    return remote ?? LiturgicalCountdownSettings.automatic(year);
  },
);

/// Cuenta atrás visible en Calendario y Foros.
final cofradeCountdownProvider = Provider<CofradeCountdown?>((ref) {
  final now = DateTime.now();
  final year = now.year;
  final settingsAsync = ref.watch(liturgicalCountdownSettingsProvider(year));

  return settingsAsync.when(
    data: (settings) => cofradeCountdownFor(now, settings: settings),
    loading: () => cofradeCountdownFor(
      now,
      settings: LiturgicalCountdownSettings.automatic(year),
    ),
    error: (_, _) => cofradeCountdownFor(
      now,
      settings: LiturgicalCountdownSettings.automatic(year),
    ),
  );
});

void invalidateLiturgicalCountdown(WidgetRef ref, {int? year}) {
  final y = year ?? DateTime.now().year;
  ref.invalidate(liturgicalCountdownSettingsProvider(y));
  ref.invalidate(liturgicalCountdownSettingsProvider(y + 1));
}

void refreshLiturgicalCountdownFromRemote(Ref ref, {int? year}) {
  final y = year ?? DateTime.now().year;
  ref.invalidate(liturgicalCountdownSettingsProvider(y));
  ref.invalidate(liturgicalCountdownSettingsProvider(y + 1));
}

/// Realtime: activar/ocultar banner y días de antelación sin recargar la app.
final liturgicalCountdownRealtimeProvider = Provider<void>((ref) {
  if (SupabaseBootstrap.client == null) return;

  final client = SupabaseBootstrap.client!;

  final channel = client
      .channel('liturgical-countdown-sync')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'liturgical_countdown_settings',
        callback: (_) => refreshLiturgicalCountdownFromRemote(ref),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});