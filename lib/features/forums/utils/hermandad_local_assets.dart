import 'package:flutter/services.dart';

/// Assets locales por hermandad:
/// `assets/images/hermandades/{Día}/{Nombre}/fondo_….png`
abstract final class HermandadLocalAssets {
  static Set<String> _assets = {};
  static var _ready = false;

  static bool get isReady => _ready;

  static Future<void> ensureLoaded({bool force = false}) async {
    if (_ready && !force) return;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _assets = manifest
        .listAssets()
        .where((path) => path.startsWith('assets/images/hermandades/'))
        .toSet();
    _ready = true;
  }

  static List<String> _fondoCandidates(String dir, String slug, String slugHyphen) => [
        'fondo_$slug.png',
        'fondo_$slug.jpg',
        'fondo_$slug.jpeg',
        if (slugHyphen != slug) ...[
          'fondo_$slugHyphen.png',
          'fondo_$slugHyphen.jpg',
          'fondo_$slugHyphen.jpeg',
        ],
        'fondo.png',
        'fondo.jpg',
        'fondo.jpeg',
      ].map((file) => '$dir$file').toList();

  static List<String> _avatarCandidates(String dir, String slug, String slugHyphen) => [
        'escudo_$slug.png',
        'escudo_$slug.jpg',
        'escudo_$slug.jpeg',
        'avatar_$slug.png',
        'avatar_$slug.jpg',
        'avatar_$slug.jpeg',
        if (slugHyphen != slug) ...[
          'escudo_$slugHyphen.png',
          'escudo_$slugHyphen.jpg',
          'escudo_$slugHyphen.jpeg',
          'avatar_$slugHyphen.png',
          'avatar_$slugHyphen.jpg',
          'avatar_$slugHyphen.jpeg',
        ],
        'escudo.png',
        'escudo.jpg',
        'escudo.jpeg',
        'avatar.png',
        'avatar.jpg',
        'avatar.jpeg',
      ].map((file) => '$dir$file').toList();

  /// Fondo de card (wash) si existe en la carpeta de la hermandad.
  static String? cardWash({
    required String? processionDay,
    required String hermandadName,
  }) {
    if (!_ready || processionDay == null || processionDay.isEmpty) {
      return null;
    }
    final name = hermandadName.trim();
    if (name.isEmpty) return null;

    final dir = 'assets/images/hermandades/$processionDay/$name/';
    final slug = hermandadAssetSlug(name);
    final slugHyphen = hermandadAssetSlugHyphen(name);
    for (final path in _fondoCandidates(dir, slug, slugHyphen)) {
      if (_assets.contains(path)) return path;
    }

    // Fallback por slug (por si la carpeta tiene encoding distinto en disco).
    final daySlug = hermandadAssetSlug(processionDay);
    final nameSlug = hermandadAssetSlug(name);
    final fuzzy = _assets.where((path) {
      final key = hermandadAssetSlug(path);
      return key.contains(daySlug) &&
          key.contains(nameSlug) &&
          path.split('/').last.toLowerCase().startsWith('fondo');
    }).toList()
      ..sort();
    if (fuzzy.isNotEmpty) return fuzzy.first;

    final matches = _assets
        .where(
          (path) =>
              path.startsWith(dir) &&
              path.split('/').last.toLowerCase().startsWith('fondo'),
        )
        .toList()
      ..sort();
    return matches.isEmpty ? null : matches.first;
  }

  /// Escudo/avatar circular si existe (`avatar.png`, `escudo.png`, …).
  static String? avatar({
    required String? processionDay,
    required String hermandadName,
  }) {
    if (!_ready || processionDay == null || processionDay.isEmpty) {
      return null;
    }
    final name = hermandadName.trim();
    if (name.isEmpty) return null;

    final dir = 'assets/images/hermandades/$processionDay/$name/';
    final slug = hermandadAssetSlug(name);
    final slugHyphen = hermandadAssetSlugHyphen(name);
    for (final path in _avatarCandidates(dir, slug, slugHyphen)) {
      if (_assets.contains(path)) return path;
    }

    final daySlug = hermandadAssetSlug(processionDay);
    final nameSlug = hermandadAssetSlug(name);
    final fuzzy = _assets.where((path) {
      final key = hermandadAssetSlug(path);
      final file = path.split('/').last.toLowerCase();
      return key.contains(daySlug) &&
          key.contains(nameSlug) &&
          (file.startsWith('avatar') || file.startsWith('escudo'));
    }).toList()
      ..sort();
    return fuzzy.isEmpty ? null : fuzzy.first;
  }
}

/// `Bendición y Esperanza` → `bendicionesperanza`
String hermandadAssetSlug(String name) {
  return _normalizeHermandadAssetKey(name).replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

/// `Pino Montano` → `pino-montano`
String hermandadAssetSlugHyphen(String name) {
  return _normalizeHermandadAssetKey(name)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _normalizeHermandadAssetKey(String name) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final lower = name.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(accents[ch] ?? ch);
  }
  return buf.toString();
}
