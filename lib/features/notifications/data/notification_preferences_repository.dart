import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/notification_preferences.dart';

class NotificationPreferencesRepository {
  NotificationPreferencesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<NotificationPreferences> fetch(String userId) async {
    if (_client == null) return const NotificationPreferences();

    final row = await _client!
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return const NotificationPreferences();
    return _fromRow(row);
  }

  Future<void> save({
    required String userId,
    required NotificationPreferences prefs,
  }) async {
    if (_client == null) throw const NotificationPreferencesUnavailable();

    await _client!.from('notification_preferences').upsert({
      'user_id': userId,
      'notify_hashtags': prefs.notifyHashtags,
      'notify_profiles': prefs.notifyProfiles,
      'notify_topics': prefs.notifyTopics,
      'notify_mentions': prefs.notifyMentions,
      'notify_followers': prefs.notifyFollowers,
      'push_enabled': prefs.pushEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  NotificationPreferences _fromRow(Map<String, dynamic> row) {
    return NotificationPreferences(
      notifyHashtags: row['notify_hashtags'] as bool? ?? true,
      notifyProfiles: row['notify_profiles'] as bool? ?? true,
      notifyTopics: row['notify_topics'] as bool? ?? true,
      notifyMentions: row['notify_mentions'] as bool? ?? true,
      notifyFollowers: row['notify_followers'] as bool? ?? false,
      pushEnabled: row['push_enabled'] as bool? ?? false,
    );
  }
}

class NotificationPreferencesUnavailable implements Exception {
  const NotificationPreferencesUnavailable();
}

NotificationPreferencesRepository createNotificationPreferencesRepository() {
  return NotificationPreferencesRepository(client: SupabaseBootstrap.client);
}
