import '../../../shared/models/calendar_event.dart';

export '../../../shared/models/calendar_event.dart' show SeasonPaso;

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
    this.igualaSplit = false,
    this.ensayoSplit = false,
    this.ensayoCount = 1,
    this.mudaMode = MudaRetranqueoMode.mudaOnly,
  });

  final bool igualaSplit;
  final bool ensayoSplit;
  final int ensayoCount;
  final MudaRetranqueoMode mudaMode;

  static const defaults = HermandadSeasonProfile();

  HermandadSeasonProfile copyWith({
    bool? igualaSplit,
    bool? ensayoSplit,
    int? ensayoCount,
    MudaRetranqueoMode? mudaMode,
  }) {
    return HermandadSeasonProfile(
      igualaSplit: igualaSplit ?? this.igualaSplit,
      ensayoSplit: ensayoSplit ?? this.ensayoSplit,
      ensayoCount: ensayoCount ?? this.ensayoCount,
      mudaMode: mudaMode ?? this.mudaMode,
    );
  }

  Map<String, dynamic> toDb(String topicId) => {
        'topic_id': topicId,
        'iguala_split': igualaSplit,
        'ensayo_split': ensayoSplit,
        'ensayo_count': ensayoCount.clamp(1, 12),
        'muda_mode': mudaMode.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  static HermandadSeasonProfile fromRow(Map<String, dynamic> row) {
    return HermandadSeasonProfile(
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
