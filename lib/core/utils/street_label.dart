/// Texto que no aporta la calle: el aviso aún no ha resuelto la dirección.
bool isGenericPlaceLabel(String? label) {
  final text = (label ?? '').trim().toLowerCase();
  if (text.isEmpty) return true;
  const generic = {
    'mi ubicación',
    'mi ubicacion',
    'ubicación',
    'ubicacion',
    'ver en el mapa',
  };
  return generic.contains(text);
}

/// Calle legible a partir de un resultado de geocodificación inversa.
///
/// Prefiere el nombre de la vía y el número. Descarta plus codes, la ciudad
/// sola y vías sin nombre.
String? formatStreetLabel({
  String? thoroughfare,
  String? subThoroughfare,
  String? street,
  String? name,
  String? subLocality,
  String? locality,
}) {
  final road = _usable(thoroughfare);
  final number = _usable(subThoroughfare);
  final streetLine = _usable(street);
  final poi = _usable(name);
  final barrio = _usable(subLocality);
  final city = _usable(locality);

  if (road.isNotEmpty) {
    if (number.isNotEmpty && !_containsToken(road, number)) {
      return '$road, $number';
    }
    return road;
  }

  if (streetLine.isNotEmpty) {
    return _shortenStreet(streetLine, locality: city, barrio: barrio);
  }

  if (poi.isNotEmpty && !_same(poi, city) && !_same(poi, barrio)) {
    return poi;
  }
  return null;
}

final _plusCode = RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]{2,}', caseSensitive: false);
final _postalCode = RegExp(r'^\d{4,5}$');

const _drop = {
  'unnamed road',
  'vía sin nombre',
  'via sin nombre',
  'null',
  'españa',
  'spain',
  'andalucía',
  'andalucia',
};

String _usable(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return '';
  if (_plusCode.hasMatch(text)) return '';
  if (_drop.contains(text.toLowerCase())) return '';
  return text;
}

bool _same(String a, String b) =>
    b.isNotEmpty && a.toLowerCase() == b.toLowerCase();

bool _containsToken(String haystack, String token) {
  return haystack.toLowerCase().contains(token.toLowerCase());
}

String _shortenStreet(
  String street, {
  required String locality,
  required String barrio,
}) {
  final parts = street
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .where((part) {
        if (_same(part, locality) || _same(part, barrio)) return false;
        if (_postalCode.hasMatch(part)) return false;
        if (_drop.contains(part.toLowerCase())) return false;
        if (_plusCode.hasMatch(part)) return false;
        return true;
      })
      .toList();
  if (parts.isEmpty) return street;
  if (parts.length >= 2 && RegExp(r'^\d').hasMatch(parts[1])) {
    return '${parts[0]}, ${parts[1]}';
  }
  return parts.first;
}
