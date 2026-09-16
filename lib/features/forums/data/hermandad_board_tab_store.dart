import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda la última pestaña del tablón por hermandad.
class HermandadBoardTabStore {
  static const _prefix = 'hermandad_board_tab_';

  static Future<String?> load(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_prefix$topicId');
    if (value == null || value == 'all') return null;
    return value;
  }

  static Future<void> save(String topicId, String? category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$topicId', category ?? 'all');
  }
}
