import 'package:shared_preferences/shared_preferences.dart';

import '../utils/official_post_categories.dart';

/// Recuerda la última pestaña del tablón por hermandad.
class HermandadBoardTabStore {
  static const _prefix = 'hermandad_board_tab_';
  static const defaultCategory = 'noticia';

  static Future<String> load(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_prefix$topicId');
    if (value == null || value == 'all' || value.isEmpty) {
      return defaultCategory;
    }
    final valid = officialPostCategories.any((c) => c.value == value);
    return valid ? value : defaultCategory;
  }

  static Future<void> save(String topicId, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = officialPostCategories.any((c) => c.value == category);
    await prefs.setString(
      '$_prefix$topicId',
      valid ? category : defaultCategory,
    );
  }
}
