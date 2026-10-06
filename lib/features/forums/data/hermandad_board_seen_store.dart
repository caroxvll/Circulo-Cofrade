import 'package:shared_preferences/shared_preferences.dart';

import '../utils/official_post_categories.dart';

/// Marca de «última visita» por sección del tablón oficial.
///
/// Sirve para mostrar solo entradas *nuevas* en los chips (no el total).
class HermandadBoardSeenStore {
  static const _prefix = 'hermandad_board_seen_';

  static String _key(String topicId, String category) =>
      '$_prefix${topicId}_$category';

  static Future<DateTime?> load(String topicId, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(topicId, category));
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> markSeen(
    String topicId,
    String category, {
    DateTime? at,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(topicId, category),
      (at ?? DateTime.now()).toUtc().toIso8601String(),
    );
  }

  /// Primera visita: fija «ahora» en todas las secciones para no marcar
  /// el histórico como novedad.
  static Future<void> seedIfNeeded(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final cat in officialPostCategories) {
      final key = _key(topicId, cat.value);
      if (!prefs.containsKey(key)) {
        await prefs.setString(key, now);
      }
    }
  }

  static Future<Map<String, DateTime>> loadAll(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, DateTime>{};
    for (final cat in officialPostCategories) {
      final raw = prefs.getString(_key(topicId, cat.value));
      if (raw == null || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) result[cat.value] = parsed;
    }
    return result;
  }
}
