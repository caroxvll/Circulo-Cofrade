import '../models/ss_live_update.dart';

/// Centro aproximado del casco histórico de Sevilla.
const sevillaMapCenterLat = 37.3886;
const sevillaMapCenterLng = -5.9953;

class SsLiveStats {
  const SsLiveStats({
    required this.retrasos,
    required this.enRecorrido,
    required this.incidentes,
    required this.avisos,
    required this.curiosidades,
    required this.total,
  });

  final int retrasos;
  final int enRecorrido;
  final int incidentes;
  final int avisos;
  final int curiosidades;
  final int total;

  factory SsLiveStats.fromUpdates(List<SsLiveUpdate> updates) {
    var retrasos = 0;
    var enRecorrido = 0;
    var incidentes = 0;
    var avisos = 0;
    var curiosidades = 0;
    for (final u in updates) {
      switch (u.kind) {
        case SsLiveUpdateKind.retraso:
          retrasos++;
        case SsLiveUpdateKind.posicion:
          enRecorrido++;
        case SsLiveUpdateKind.incidente:
          incidentes++;
        case SsLiveUpdateKind.general:
          avisos++;
        case SsLiveUpdateKind.curiosidad:
          curiosidades++;
      }
    }
    return SsLiveStats(
      retrasos: retrasos,
      enRecorrido: enRecorrido,
      incidentes: incidentes,
      avisos: avisos,
      curiosidades: curiosidades,
      total: updates.length,
    );
  }
}

/// Hermandad en el mapa: punto actual + rastro de posiciones publicadas.
class SsHermandadTrack {
  const SsHermandadTrack({
    required this.key,
    required this.hermandadLabel,
    required this.pointsOldestFirst,
    required this.latest,
  });

  final String key;
  final String hermandadLabel;
  final List<SsLiveUpdate> pointsOldestFirst;
  final SsLiveUpdate latest;

  double get latitude => latest.latitude!;
  double get longitude => latest.longitude!;

  int get pointCount => pointsOldestFirst.length;

  String get shortLabel {
    final raw = hermandadLabel.trim();
    if (raw.length <= 18) return raw;
    return '${raw.substring(0, 16)}…';
  }
}

List<String> ssHermandadLabels(List<SsLiveUpdate> updates) {
  final seen = <String>{};
  final labels = <String>[];
  for (final u in updates) {
    final label = u.hermandadLabel?.trim();
    if (label == null || label.isEmpty) continue;
    if (seen.add(label)) labels.add(label);
  }
  labels.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return labels;
}

List<SsLiveUpdate> filterSsUpdates(
  List<SsLiveUpdate> updates, {
  SsLiveUpdateKind? kind,
  String? hermandad,
}) {
  final hermandadKey = hermandad?.trim().toLowerCase();
  return updates.where((u) {
    if (kind != null && u.kind != kind) return false;
    if (hermandadKey != null && hermandadKey.isNotEmpty) {
      final label = u.hermandadLabel?.trim().toLowerCase() ?? '';
      if (label != hermandadKey) return false;
    }
    return true;
  }).toList();
}

String _trackKey(SsLiveUpdate u) {
  final label = u.hermandadLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return 'h:${label.toLowerCase()}';
  }
  return 'c:${u.latitude!.toStringAsFixed(3)},${u.longitude!.toStringAsFixed(3)}';
}

/// Solo avisos de posición con coords → 1 track por hermandad.
/// El rastro se construye uniendo publicaciones en orden temporal.
List<SsHermandadTrack> buildSsHermandadTracks(
  List<SsLiveUpdate> updates, {
  String? hermandad,
}) {
  final hermandadKey = hermandad?.trim().toLowerCase();
  final posicion = updates.where((u) {
    if (u.kind != SsLiveUpdateKind.posicion || !u.hasCoordinates) return false;
    if (hermandadKey != null && hermandadKey.isNotEmpty) {
      final label = u.hermandadLabel?.trim().toLowerCase() ?? '';
      if (label != hermandadKey) return false;
    }
    return true;
  }).toList();

  final byKey = <String, List<SsLiveUpdate>>{};
  for (final u in posicion) {
    byKey.putIfAbsent(_trackKey(u), () => []).add(u);
  }

  final tracks = <SsHermandadTrack>[];
  for (final entry in byKey.entries) {
    final list = entry.value
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Suavizado simple: si dos puntos están casi encima, nos quedamos con el más reciente.
    final simplified = <SsLiveUpdate>[];
    for (final u in list) {
      if (simplified.isEmpty) {
        simplified.add(u);
        continue;
      }
      final prev = simplified.last;
      final dLat = (u.latitude! - prev.latitude!).abs();
      final dLng = (u.longitude! - prev.longitude!).abs();
      if (dLat < 0.00015 && dLng < 0.00015) {
        simplified[simplified.length - 1] = u;
      } else {
        simplified.add(u);
      }
    }

    final latest = simplified.last;
    final label = latest.hermandadLabel?.trim().isNotEmpty == true
        ? latest.hermandadLabel!.trim()
        : (latest.placeLabel?.trim().isNotEmpty == true
            ? latest.placeLabel!.trim()
            : 'Hermandad');

    tracks.add(
      SsHermandadTrack(
        key: entry.key,
        hermandadLabel: label,
        pointsOldestFirst: simplified,
        latest: latest,
      ),
    );
  }

  tracks.sort((a, b) => b.latest.createdAt.compareTo(a.latest.createdAt));
  return tracks;
}
