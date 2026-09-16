import 'package:shared_preferences/shared_preferences.dart';

const _keyPrefix = 'event_bookmarks_';

class EventBookmarksStore {
  Future<Set<String>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_keyPrefix$userId');
    if (list == null) return {};
    return list.toSet();
  }

  Future<void> save(String userId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_keyPrefix$userId', ids.toList());
  }
}
