import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import 'street_label.dart';

final _geocoding = Geocoding(locale: const Locale('es', 'ES'));

final _cache = <String, String>{};
final _inflight = <String, Future<String?>>{};
bool? _geocoderPresent;

/// Nombre de calle para unas coordenadas. Vacío si el teléfono no puede
/// resolverlas. Las consultas repetidas de la misma esquina salen de memoria.
Future<String?> streetNameForCoordinates(
  double latitude,
  double longitude,
) {
  final key = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
  final cached = _cache[key];
  if (cached != null) return Future.value(cached.isEmpty ? null : cached);
  return _inflight[key] ??= _resolve(key, latitude, longitude);
}

Future<String?> _resolve(String key, double latitude, double longitude) async {
  try {
    final present = _geocoderPresent ??= await _geocoding.isPresent();
    if (!present) return null;
    final marks = await _geocoding.placemarkFromCoordinates(
      latitude,
      longitude,
    );
    for (final mark in marks) {
      final label = formatStreetLabel(
        thoroughfare: mark.thoroughfare,
        subThoroughfare: mark.subThoroughfare,
        street: mark.street,
        name: mark.name,
        subLocality: mark.subLocality,
        locality: mark.locality,
      );
      if (label != null) {
        _cache[key] = label;
        return label;
      }
    }
    _cache[key] = '';
    return null;
  } catch (_) {
    return null;
  } finally {
    _inflight.remove(key);
  }
}
