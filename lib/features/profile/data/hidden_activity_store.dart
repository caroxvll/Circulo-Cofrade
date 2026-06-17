import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/profile_activity.dart';

const _keyPrefix = 'profile_hidden_activity_';

class HiddenActivityStore {
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

  Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$userId');
  }
}

enum ActivityFeedFilter { all, topics, replies }

String activityFilterLabel(ActivityFeedFilter filter) {
  return switch (filter) {
    ActivityFeedFilter.all => 'Todo',
    ActivityFeedFilter.topics => 'Temas',
    ActivityFeedFilter.replies => 'Respuestas',
  };
}

List<ProfileActivity> filterActivities(
  List<ProfileActivity> activities,
  ActivityFeedFilter filter,
  Set<String> hiddenIds,
) {
  return activities.where((a) {
    if (hiddenIds.contains(a.id)) return false;
    return switch (filter) {
      ActivityFeedFilter.all => true,
      ActivityFeedFilter.topics => a.isTopic,
      ActivityFeedFilter.replies => !a.isTopic,
    };
  }).toList();
}
