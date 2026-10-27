import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class SsLiturgicalDay {
  const SsLiturgicalDay({
    required this.dayKey,
    required this.label,
    required this.year,
    required this.startsAt,
    required this.endsAt,
    required this.forceState,
    required this.isOpen,
  });

  final String dayKey;
  final String label;
  final int year;
  final DateTime startsAt;
  final DateTime endsAt;
  final String forceState;
  final bool isOpen;
}

class SsLiveGateState {
  const SsLiveGateState({
    required this.isOpen,
    this.activeDay,
    this.settingsLoaded = true,
  });

  final bool isOpen;
  final SsLiturgicalDay? activeDay;
  final bool settingsLoaded;

  /// La jornada está forzada o dentro de horario, pero el interruptor
  /// general de Temporada («En directo de Semana Santa») está apagado.
  bool get pausedByMasterSwitch =>
      !isOpen && activeDay != null && activeDay!.isOpen;

  String get closedMessage {
    if (isOpen) return '';
    final day = activeDay;
    if (day != null && day.isOpen) {
      return 'El en directo está en pausa. En Temporada, activa '
          '«En directo de Semana Santa», en Perfil → Junta → Temporada. '
          'La jornada «${day.label}» está abierta.';
    }
    if (day == null) {
      return 'El en directo está cerrado. Vuelve en la próxima jornada.';
    }
    return 'La jornada «${day.label}» no admite avisos ahora.';
  }
}

class SsLiveGateRepository {
  SsLiveGateRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<bool> fetchLiveEnabled() async {
    final client = _client;
    if (client == null) return true;
    final row = await client
        .from('ss_live_settings')
        .select('is_enabled')
        .eq('id', 1)
        .maybeSingle();
    return row?['is_enabled'] as bool? ?? true;
  }

  Future<void> setLiveEnabled(bool enabled) async {
    final client = _client;
    if (client == null) return;
    await client.from('ss_live_settings').upsert({
      'id': 1,
      'is_enabled': enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<SsLiveGateState> fetchGate() async {
    final client = _client;
    if (client == null) {
      return const SsLiveGateState(isOpen: true);
    }

    try {
      final open = await client.rpc('ss_live_is_open');
      final isOpen = open == true;

      SsLiturgicalDay? active;
      try {
        final rows = await client.rpc('ss_current_liturgical_day');
        if (rows is List && rows.isNotEmpty) {
          final map = rows.first as Map<String, dynamic>;
          active = SsLiturgicalDay(
            dayKey: map['day_key'] as String? ?? '',
            label: map['label'] as String? ?? 'Jornada',
            year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
            startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
            endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
            forceState: map['force_state'] as String? ?? 'auto',
            isOpen: map['is_open'] == true,
          );
        }
      } catch (_) {
        // Función no desplegada aún.
      }

      return SsLiveGateState(isOpen: isOpen, activeDay: active);
    } catch (_) {
      // Sin SQL de jornadas → no bloquear publicación.
      return const SsLiveGateState(isOpen: true, settingsLoaded: false);
    }
  }
}

SsLiveGateRepository createSsLiveGateRepository() {
  return SsLiveGateRepository(client: SupabaseBootstrap.client);
}

final ssLiveGateRepositoryProvider = Provider<SsLiveGateRepository>((ref) {
  return createSsLiveGateRepository();
});

final ssLiveMasterEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(ssLiveGateRepositoryProvider).fetchLiveEnabled();
});

final ssLiveGateProvider = FutureProvider.autoDispose<SsLiveGateState>((ref) {
  ref.keepAlive();
  return ref.watch(ssLiveGateRepositoryProvider).fetchGate();
});
