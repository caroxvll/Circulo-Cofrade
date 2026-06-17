import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../../shared/models/notification_preferences.dart';
import 'data/notification_preferences_repository.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
  return createNotificationPreferencesRepository();
});

final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(notificationPreferencesRepositoryProvider);
    if (user == null || !repo.isAvailable) {
      return const NotificationPreferences();
    }
    return repo.fetch(user.id);
  }

  Future<void> updatePref({
    bool? notifyHashtags,
    bool? notifyProfiles,
    bool? notifyTopics,
    bool? notifyMentions,
    bool? notifyFollowers,
    bool? pushEnabled,
  }) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationPreferencesRepositoryProvider);
    if (user == null || !repo.isAvailable) return;

    final current = state.asData?.value ?? const NotificationPreferences();
    final next = current.copyWith(
      notifyHashtags: notifyHashtags,
      notifyProfiles: notifyProfiles,
      notifyTopics: notifyTopics,
      notifyMentions: notifyMentions,
      notifyFollowers: notifyFollowers,
      pushEnabled: pushEnabled,
    );

    state = AsyncData(next);
    try {
      await repo.save(userId: user.id, prefs: next);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}
