import '../../../shared/models/calendar_event.dart';

export '../../../shared/models/calendar_event.dart' show SeasonPaso;

/// Cuántos pasos saca la hermandad (y de qué tipo).
enum HermandadPasosLayout {
  cristo,
  virgen,
  cristoVirgen,
  dosCristosVirgen;

  static HermandadPasosLayout fromDb(String? raw) => switch (raw) {
        'cristo' => HermandadPasosLayout.cristo,
        'virgen' => HermandadPasosLayout.virgen,
        'dos_cristos_virgen' => HermandadPasosLayout.dosCristosVirgen,
        _ => HermandadPasosLayout.cristoVirgen,
      };

  String get dbValue => switch (this) {
        HermandadPasosLayout.cristo => 'cristo',
        HermandadPasosLayout.virgen => 'virgen',
        HermandadPasosLayout.cristoVirgen => 'cristo_virgen',
        HermandadPasosLayout.dosCristosVirgen => 'dos_cristos_virgen',
      };

  String get label => switch (this) {
        HermandadPasosLayout.cristo => 'Solo Cristo',
        HermandadPasosLayout.virgen => 'Solo Virgen',
        HermandadPasosLayout.cristoVirgen => 'Cristo y Virgen',
        HermandadPasosLayout.dosCristosVirgen => 'Dos Cristos y Virgen',
      };

  String get subtitle => switch (this) {
        HermandadPasosLayout.cristo =>
          'Un solo paso. Igualá y ensayos se marcan una vez.',
        HermandadPasosLayout.virgen =>
          'Un solo paso. Igualá y ensayos se marcan una vez.',
        HermandadPasosLayout.cristoVirgen =>
          'Lo habitual: misterio y palio.',
        HermandadPasosLayout.dosCristosVirgen =>
          'Tres pasos: Cristo 1, Cristo 2 y Virgen, cada uno aparte.',
      };

  List<SeasonPaso> get trackedPasos => switch (this) {
        HermandadPasosLayout.cristo => const [SeasonPaso.cristo],
        HermandadPasosLayout.virgen => const [SeasonPaso.virgen],
        HermandadPasosLayout.cristoVirgen => const [
            SeasonPaso.cristo,
            SeasonPaso.virgen,
          ],
        HermandadPasosLayout.dosCristosVirgen => const [
            SeasonPaso.cristo,
            SeasonPaso.cristo2,
            SeasonPaso.virgen,
          ],
      };

  /// Chips al crear el evento. Un solo paso no pide elegir.
  List<SeasonPaso> get eventChoices => switch (this) {
        HermandadPasosLayout.cristo => const [SeasonPaso.cristo],
        HermandadPasosLayout.virgen => const [SeasonPaso.virgen],
        HermandadPasosLayout.cristoVirgen => const [
            SeasonPaso.ambos,
            SeasonPaso.cristo,
            SeasonPaso.virgen,
          ],
        HermandadPasosLayout.dosCristosVirgen => const [
            SeasonPaso.cristo,
            SeasonPaso.cristo2,
            SeasonPaso.virgen,
          ],
      };

  SeasonPaso get defaultPaso => trackedPasos.first;

  bool get hasMultiplePasos => trackedPasos.length > 1;

  bool get canSplitPasos => this == HermandadPasosLayout.cristoVirgen;

  String slotLabel(SeasonPaso paso) => switch (paso) {
        SeasonPaso.ambos => 'Ambos',
        SeasonPaso.cristo =>
          this == HermandadPasosLayout.dosCristosVirgen ? 'Cristo 1' : 'Cristo',
        SeasonPaso.cristo2 => 'Cristo 2',
        SeasonPaso.virgen => 'Virgen',
      };

  String eventChipLabel(SeasonPaso paso) => slotLabel(paso);

  bool splitsIguala(bool igualaSplit) =>
      this == HermandadPasosLayout.dosCristosVirgen ||
      (canSplitPasos && igualaSplit);

  bool splitsEnsayo(bool ensayoSplit) =>
      this == HermandadPasosLayout.dosCristosVirgen ||
      (canSplitPasos && ensayoSplit);

  SeasonPaso resolvedEventPaso(SeasonPaso selected) {
    if (eventChoices.contains(selected)) return selected;
    return defaultPaso;
  }
}

enum MudaRetranqueoMode {
  withRetranqueo,
  split,
  mudaOnly;

  static MudaRetranqueoMode fromDb(String? raw) => switch (raw) {
        'with_retranqueo' => MudaRetranqueoMode.withRetranqueo,
        'split' => MudaRetranqueoMode.split,
        _ => MudaRetranqueoMode.mudaOnly,
      };

  String get dbValue => switch (this) {
        MudaRetranqueoMode.withRetranqueo => 'with_retranqueo',
        MudaRetranqueoMode.split => 'split',
        MudaRetranqueoMode.mudaOnly => 'muda_only',
      };

  String get label => switch (this) {
        MudaRetranqueoMode.withRetranqueo =>
          'Muda con retranqueo el mismo día',
        MudaRetranqueoMode.split => 'Muda un día y retranqueo otro',
        MudaRetranqueoMode.mudaOnly => 'Solo muda',
      };

  String get shortLabel => switch (this) {
        MudaRetranqueoMode.withRetranqueo => 'Muda+retr.',
        MudaRetranqueoMode.split => 'Muda / retr.',
        MudaRetranqueoMode.mudaOnly => 'Muda',
      };
}

class HermandadSeasonProfile {
  const HermandadSeasonProfile({
    this.pasosLayout = HermandadPasosLayout.cristoVirgen,
    this.igualaSplit = false,
    this.ensayoSplit = false,
    this.ensayoCount = 1,
    this.mudaMode = MudaRetranqueoMode.mudaOnly,
  });

  final HermandadPasosLayout pasosLayout;
  final bool igualaSplit;
  final bool ensayoSplit;
  final int ensayoCount;
  final MudaRetranqueoMode mudaMode;

  static const defaults = HermandadSeasonProfile();

  HermandadSeasonProfile copyWith({
    HermandadPasosLayout? pasosLayout,
    bool? igualaSplit,
    bool? ensayoSplit,
    int? ensayoCount,
    MudaRetranqueoMode? mudaMode,
  }) {
    return HermandadSeasonProfile(
      pasosLayout: pasosLayout ?? this.pasosLayout,
      igualaSplit: igualaSplit ?? this.igualaSplit,
      ensayoSplit: ensayoSplit ?? this.ensayoSplit,
      ensayoCount: ensayoCount ?? this.ensayoCount,
      mudaMode: mudaMode ?? this.mudaMode,
    );
  }

  Map<String, dynamic> toDb(String topicId) => {
        'topic_id': topicId,
        'pasos_layout': pasosLayout.dbValue,
        'iguala_split': igualaSplit,
        'ensayo_split': ensayoSplit,
        'ensayo_count': ensayoCount.clamp(1, 12),
        'muda_mode': mudaMode.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  static HermandadSeasonProfile fromRow(Map<String, dynamic> row) {
    return HermandadSeasonProfile(
      pasosLayout: HermandadPasosLayout.fromDb(row['pasos_layout'] as String?),
      igualaSplit: row['iguala_split'] == true,
      ensayoSplit: row['ensayo_split'] == true,
      ensayoCount: (row['ensayo_count'] as num?)?.toInt().clamp(1, 12) ?? 1,
      mudaMode: MudaRetranqueoMode.fromDb(row['muda_mode'] as String?),
    );
  }
}

String ordinalEnsayo(int n) {
  return switch (n) {
    1 => '1º ensayo',
    2 => '2º ensayo',
    3 => '3º ensayo',
    _ => '$nº ensayo',
  };
}

String seasonActDayLabel({
  required String typeDb,
  required SeasonPaso paso,
  int? seasonN,
  bool withRetranqueo = false,
}) {
  final pasoBit = switch (paso) {
    SeasonPaso.ambos => '',
    SeasonPaso.cristo => ' Cristo',
    SeasonPaso.cristo2 => ' Cristo 2',
    SeasonPaso.virgen => ' Virgen',
  };
  if (typeDb == 'ensayo') {
    final n = seasonN == null ? 'Ensayo' : ordinalEnsayo(seasonN);
    return '$n$pasoBit'.trim();
  }
  if (typeDb == 'iguala') return 'Igualá$pasoBit'.trim();
  if (typeDb == 'muda') {
    return withRetranqueo ? 'Muda y retranqueo' : 'Muda$pasoBit'.trim();
  }
  if (typeDb == 'retranqueo') return 'Retranqueo$pasoBit'.trim();
  if (typeDb == 'desarma') return 'Desarmá';
  return '';
}
