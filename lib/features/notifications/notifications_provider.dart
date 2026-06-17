import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../auth/auth_provider.dart';
import '../../shared/models/app_notification.dart';
import '../profile/profile_provider.dart';
import 'data/mock_notifications.dart';
import 'data/notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return createNotificationsRepository();
});

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// Suscripción Realtime: mantiene la bandeja al día sin refrescar manualmente.
final notificationsRealtimeProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(notificationsRepositoryProvider);
  if (user == null || !repo.isAvailable) return;

  final client = SupabaseBootstrap.client;
  if (client == null) return;

  final channel = client
      .channel('notifications-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (_) {
          ref.read(notificationsProvider.notifier).silentRefresh();
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final user = ref.watch(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    if (user != null && repo.isAvailable) {
      final list = await repo.fetchForUser(user.id);
      _syncProfileActivity(user.id, list);
      return list;
    }
    return List<AppNotification>.from(mockNotifications);
  }

  void _syncProfileActivity(String userId, List<AppNotification> list) {
    final hasModerationUpdate = list.any(
      (n) =>
          n.kind == AppNotificationKind.topicPublished ||
          n.kind == AppNotificationKind.topicRejected,
    );
    if (!hasModerationUpdate) return;

    Future.microtask(() {
      ref.invalidate(userActivityProvider(userId));
    });
  }

  /// El contador de seguidores en BD ya se actualiza; el perfil en caché no.
  void _syncFollowerCountIfNeeded(
    List<AppNotification>? previous,
    List<AppNotification> list,
  ) {
    if (previous == null) return;

    final previousIds = previous.map((n) => n.id).toSet();
    final newFollower = list.any(
      (n) =>
          n.kind == AppNotificationKind.newFollower &&
          !previousIds.contains(n.id),
    );
    if (!newFollower) return;

    Future.microtask(() {
      ref.invalidate(currentUserProfileProvider);
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  /// Recarga sin spinner (Realtime, push en primer plano, cambio de pestaña).
  Future<void> silentRefresh() async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    if (user == null || !repo.isAvailable) return;

    try {
      final previous = state.asData?.value;
      final list = await repo.fetchForUser(user.id);
      _syncProfileActivity(user.id, list);
      _syncFollowerCountIfNeeded(previous, list);
      state = AsyncData(list);
    } catch (_) {
      // Mantener el estado anterior si falla la red.
    }
  }

  Future<void> markAllRead() async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData([
        for (final n in current) n.copyWith(isRead: true),
      ]);
    }

    if (user != null && repo.isAvailable) {
      try {
        await repo.markAllRead(user.id);
      } catch (_) {
        await refresh();
      }
      return;
    }

    if (current == null) {
      final mock = mockNotifications;
      state = AsyncData([
        for (final n in mock) n.copyWith(isRead: true),
      ]);
    }
  }

  Future<void> markRead(String id) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    if (user != null && repo.isAvailable) {
      await repo.markRead(user.id, id);
      await refresh();
      return;
    }

    final current = state.asData?.value ?? mockNotifications;
    state = AsyncData([
      for (final n in current)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);
  }

  Future<void> dismiss(String id) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData([
        for (final n in current) if (n.id != id) n,
      ]);
    }

    if (user != null && repo.isAvailable) {
      try {
        await repo.delete(user.id, id);
      } catch (_) {
        await refresh();
      }
      return;
    }

    if (current == null) {
      final mock = state.asData?.value ?? mockNotifications;
      state = AsyncData([
        for (final n in mock) if (n.id != id) n,
      ]);
    }
  }

  Future<void> clearAll() async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    if (user != null && repo.isAvailable) {
      await repo.deleteAll(user.id);
      await refresh();
      return;
    }

    state = const AsyncData([]);
  }
}

final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.maybeWhen(
    data: (list) => list.any((n) => !n.isRead),
    orElse: () => mockNotifications.any((n) => !n.isRead),
  );
});
