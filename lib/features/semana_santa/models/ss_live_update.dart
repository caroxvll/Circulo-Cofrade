enum SsLiveUpdateKind {
  retraso,
  posicion,
  incidente,
  curiosidad,
  general;

  String get dbValue => name;

  String get label => switch (this) {
        SsLiveUpdateKind.retraso => 'Retraso',
        SsLiveUpdateKind.posicion => 'Recorrido',
        SsLiveUpdateKind.incidente => 'Incidencia',
        SsLiveUpdateKind.curiosidad => 'Nota',
        SsLiveUpdateKind.general => 'Aviso',
      };

  static SsLiveUpdateKind fromDb(String? raw) {
    final value = raw?.trim().toLowerCase();
    return SsLiveUpdateKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => SsLiveUpdateKind.general,
    );
  }
}

class SsLiveUpdate {
  const SsLiveUpdate({
    required this.id,
    required this.userId,
    required this.authorHandle,
    required this.kind,
    required this.message,
    required this.createdAt,
    this.authorAvatarUrl,
    this.hermandadLabel,
    this.placeLabel,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.isOfficial = false,
  });

  final String id;
  final String userId;
  final String authorHandle;
  final String? authorAvatarUrl;
  final SsLiveUpdateKind kind;
  final String message;
  final DateTime createdAt;
  final String? hermandadLabel;
  final String? placeLabel;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final bool isOfficial;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasImage {
    final url = imageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  bool get hasMapTarget =>
      hasCoordinates || (placeLabel != null && placeLabel!.trim().isNotEmpty);
}
