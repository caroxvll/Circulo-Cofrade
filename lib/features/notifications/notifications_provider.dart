import 'dart:async';

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

/// Suscripción Realtime: parche local + debounce de refetch como red de seguridad.
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
        callback: (payload) {
          ref
              .read(notificationsProvider.notifier)
              .applyRealtimePayload(payload);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  Timer? _silentRefreshDebounce;
  var _silentRefreshGen = 0;

  @override
  Future<List<AppNotification>> build() async {
    ref.onDispose(() => _silentRefreshDebounce?.cancel());

    final user = ref.watch(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    if (user != null && repo.isAvailable) {
      final list = await repo.fetchForUser(user.id);
      _syncProfileActivity(user.id, previous: null, list: list);
      return list;
    }
    return List<AppNotification>.from(mockNotifications);
  }

  void _syncProfileActivity(
    String userId, {
    required List<AppNotification>? previous,
    required List<AppNotification> list,
  }) {
    if (previous == null) return;

    final previousIds = previous.map((n) => n.id).toSet();
    final hasNewModerationUpdate = list.any(
      (n) =>
          (n.kind == AppNotificationKind.topicPublished ||
              n.kind == AppNotificationKind.topicRejected) &&
          !previousIds.contains(n.id),
    );
    if (!hasNewModerationUpdate) return;

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

  void _syncCofradeRankIfNeeded(
    List<AppNotification>? previous,
    List<AppNotification> list,
  ) {
    if (previous == null) return;

    final previousIds = previous.map((n) => n.id).toSet();
    final rankUp = list.any(
      (n) =>
          n.kind == AppNotificationKind.cofradeRankUp &&
          !previousIds.contains(n.id),
    );
    if (!rankUp) return;

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

    final gen = ++_silentRefreshGen;
    try {
      final previous = state.asData?.value;
      final list = await repo.fetchForUser(user.id);
      if (gen != _silentRefreshGen) return;
      _syncProfileActivity(user.id, previous: previous, list: list);
      _syncFollowerCountIfNeeded(previous, list);
      _syncCofradeRankIfNeeded(previous, list);
      state = AsyncData(list);
    } catch (_) {
      // Mantener el estado anterior si falla la red.
    }
  }

  void scheduleSilentRefresh() {
    _silentRefreshDebounce?.cancel();
    _silentRefreshDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(silentRefresh());
    });
  }

  /// Parche incremental; si el payload no basta (agrupación reply reactions), refetch.
  void applyRealtimePayload(PostgresChangePayload payload) {
    final current = state.asData?.value;
    if (current == null) {
      scheduleSilentRefresh();
      return;
    }
    final repo = ref.read(notificationsRepositoryProvider);

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final parsed = repo.fromRealtimeRecord(payload.newRecord);
        if (parsed == null) {
          scheduleSilentRefresh();
          return;
        }
        // Las reacciones de reply se agrupan en fetch; mejor refetch suave.
        if (parsed.kind == AppNotificationKind.replyReaction) {
          scheduleSilentRefresh();
          return;
        }
        if (current.any((n) => n.id == parsed.id)) return;
        final next = [parsed, ...current];
        final userId = ref.read(currentUserProvider)?.id;
        if (userId != null) {
          _syncProfileActivity(userId, previous: current, list: next);
          _syncFollowerCountIfNeeded(current, next);
          _syncCofradeRankIfNeeded(current, next);
        }
        state = AsyncData(next);
        return;
      case PostgresChangeEvent.update:
        final id = payload.newRecord['id']?.toString();
        if (id == null || id.isEmpty) {
          scheduleSilentRefresh();
          return;
        }
        final readAt = payload.newRecord['read_at'];
        final isRead = readAt != null;
        var changed = false;
        final updated = <AppNotification>[];
        for (final n in current) {
          if (n.id == id) {
            updated.add(n.copyWith(isRead: isRead));
            changed = true;
          } else {
            updated.add(n);
          }
        }
        if (!changed) {
          scheduleSilentRefresh();
          return;
        }
        state = AsyncData(updated);
        return;
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id']?.toString();
        if (id == null || id.isEmpty) {
          scheduleSilentRefresh();
          return;
        }
        final next = [for (final n in current) if (n.id != id) n];
        if (next.length == current.length) return;
        state = AsyncData(next);
        return;
      case PostgresChangeEvent.all:
        scheduleSilentRefresh();
        return;
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

    final current = state.asData?.value;
    final target = current?.where((n) => n.id == id).firstOrNull;

    // Optimistic local: no esperar refresh completo de la lista.
    if (current != null) {
      if (target?.kind == AppNotificationKind.replyReaction &&
          target?.replyId != null) {
        final replyId = target!.replyId!.toLowerCase();
        state = AsyncData([
          for (final n in current)
            if (n.kind == AppNotificationKind.replyReaction &&
                n.replyId?.toLowerCase() == replyId)
              n.copyWith(isRead: true)
            else
              n,
        ]);
      } else {
        state = AsyncData([
          for (final n in current)
            if (n.id == id) n.copyWith(isRead: true) else n,
        ]);
      }
    }

    if (user != null && repo.isAvailable) {
      try {
        if (target?.kind == AppNotificationKind.replyReaction &&
            target?.replyId != null) {
          await repo.markReadReplyReactionGroup(user.id, target!.replyId!);
        } else {
          await repo.markRead(user.id, id);
        }
      } catch (_) {}
      return;
    }

    if (current == null) {
      final list = mockNotifications;
      if (target?.kind == AppNotificationKind.replyReaction &&
          target?.replyId != null) {
        final replyId = target!.replyId!.toLowerCase();
        state = AsyncData([
          for (final n in list)
            if (n.kind == AppNotificationKind.replyReaction &&
                n.replyId?.toLowerCase() == replyId)
              n.copyWith(isRead: true)
            else
              n,
        ]);
        return;
      }

      state = AsyncData([
        for (final n in list)
          if (n.id == id) n.copyWith(isRead: true) else n,
      ]);
    }
  }

  Future<void> dismiss(String id) async {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(notificationsRepositoryProvider);

    final current = state.asData?.value;
    final target = current?.where((n) => n.id == id).firstOrNull;
    final snapshot = current == null ? null : List<AppNotification>.from(current);

    if (current != null) {
      if (target?.kind == AppNotificationKind.replyReaction &&
          target?.replyId != null &&
          !target!.isRead) {
        final replyId = target.replyId!.toLowerCase();
        state = AsyncData([
          for (final n in current)
            if (!(n.kind == AppNotificationKind.replyReaction &&
                !n.isRead &&
                n.replyId?.toLowerCase() == replyId))
              n,
        ]);
      } else {
        state = AsyncData([
          for (final n in current) if (n.id != id) n,
        ]);
      }
    }

    if (user != null && repo.isAvailable) {
      try {
        if (target?.kind == AppNotificationKind.replyReaction &&
            target?.replyId != null &&
            !target!.isRead) {
          await repo.deleteUnreadReplyReactionsForReply(
            user.id,
            target.replyId!,
          );
        } else {
          await repo.delete(user.id, id);
        }
      } catch (_) {
        if (snapshot != null) {
          state = AsyncData(snapshot);
        }
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
