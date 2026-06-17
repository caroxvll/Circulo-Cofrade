import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesStore {
  RecentSearchesStore._();

  static const _key = 'recent_searches_v1';
  static const _maxItems = 8;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  static Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return load();

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    final normalized = trimmed.toLowerCase();

    final next = [
      trimmed,
      ...current.where((item) => item.toLowerCase() != normalized),
    ].take(_maxItems).toList();

    await prefs.setStringList(_key, next);
    return next;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
