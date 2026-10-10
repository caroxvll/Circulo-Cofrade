import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../shared/models/forum.dart';
import '../auth/auth_provider.dart';
import '../notifications/notifications_provider.dart';
import '../permissions/permissions_provider.dart';
import '../profile/profile_provider.dart';
import 'data/forums_repository.dart';
import 'data/forum_about_moderator.dart';
import 'data/reply_likes_repository.dart';
import 'data/topic_reactions_repository.dart';
import 'topic_replies_provider.dart';
import 'utils/noticias_forum.dart';
import 'utils/topic_list_order.dart';
import 'utils/topic_permissions.dart';
import 'viewer_id_provider.dart';

final forumsRepositoryProvider = Provider<ForumsRepository>((ref) {
  return createForumsRepository();
});

final forumPillarsProvider = FutureProvider<List<ForumCategory>>((ref) async {
  return ref.watch(forumsRepositoryProvider).fetchPillars();
});

/// Recarga metadatos de foros (portadas, iconos, nombres) tras cambios remotos.
void refreshForumPillarsFromRemote(Ref ref) {
  ref.invalidate(forumPillarsProvider);
  ref.invalidate(forumsListHeroImageProvider);
}

/// Misma invalidación desde widgets (`ConsumerWidget` / `ConsumerStatefulWidget`).
void invalidateForumPillarData(WidgetRef ref) {
  ref.invalidate(forumPillarsProvider);
  ref.invalidate(forumsListHeroImageProvider);
}

void refreshForumPillarFromRemote(Ref ref, String forumId) {
  ref.invalidate(forumPillarProvider(forumId));
  refreshForumPillarsFromRemote(ref);
}

/// Realtime: portadas/iconos de foro y hero global de la pantalla FOROS.
final forumPillarsRealtimeProvider = Provider<void>((ref) {
  if (SupabaseBootstrap.client == null) return;

  final client = SupabaseBootstrap.client!;

  final channel = client
      .channel('forum-pillars-sync')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_pillars',
        callback: (payload) {
          refreshForumPillarsFromRemote(ref);
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          final forumId = record['id']?.toString();
          if (forumId != null && forumId.isNotEmpty) {
            ref.invalidate(forumPillarProvider(forumId));
          }
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_config',
        callback: (_) => ref.invalidate(forumsListHeroImageProvider),
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

final forumsListHeroImageProvider = FutureProvider<String?>((ref) async {
  return ref.watch(forumsRepositoryProvider).fetchForumsListHeroImageUrl();
});

final forumPillarProvider = FutureProvider.family<ForumCategory?, String>((
  ref,
  forumId,
) async {
  return ref.watch(forumsRepositoryProvider).fetchPillar(forumId);
});

final forumAboutModeratorsProvider =
    FutureProvider.family<List<ForumAboutModerator>, String>((
  ref,
  forumId,
) async {
  return ref.read(forumsRepositoryProvider).fetchForumModerators(forumId);
});

final forumTopicsProvider = AsyncNotifierProvider.family<ForumTopicsNotifier,
    List<ForumTopic>, String>(
  ForumTopicsNotifier.new,
);

class ForumTopicsNotifier extends AsyncNotifier<List<ForumTopic>> {
  ForumTopicsNotifier(this.forumId);

  final String forumId;

  @override
  Future<List<ForumTopic>> build() {
    return ref.watch(forumsRepositoryProvider).fetchTopics(forumId);
  }

  Future<void> reload({bool quiet = false}) async {
    if (!quiet) state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(forumsRepositoryProvider).fetchTopics(forumId),
    );
  }

  void upsert(ForumTopic topic) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = [
      topic,
      ...current.where((t) => t.id != topic.id),
    ];
    state = AsyncData(
      List<ForumTopic>.unmodifiable(orderForumTopics(next)),
    );
  }

  void removeById(String topicId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.where((t) => t.id != topicId).toList(growable: false),
    );
  }

  void applyRealtimePayload(PostgresChangePayload payload) {
    final repo = ref.read(forumsRepositoryProvider);
    switch (payload.eventType) {
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id']?.toString();
        if (id != null && id.isNotEmpty) removeById(id);
        return;
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final id = payload.newRecord['id']?.toString();
        if (id == null || id.isEmpty) return;
        ForumTopic? previous;
        for (final t in state.asData?.value ?? const <ForumTopic>[]) {
          if (t.id == id) {
            previous = t;
            break;
          }
        }
        final parsed = repo.topicFromRealtimeRecord(
          Map<String, dynamic>.from(payload.newRecord),
          previous: previous,
        );
        if (parsed == null) return;
        // Solo publicados listados (igual que fetchTopics).
        if (!parsed.isListed || !parsed.isPublished || parsed.isRejected) {
          removeById(id);
          return;
        }
        upsert(parsed);
        return;
      case PostgresChangeEvent.all:
        return;
    }
  }
}

final forumTopicProvider = FutureProvider.autoDispose
    .family<ForumTopic?, ForumTopicKey>((ref, key) async {
      // Mantener en sesión: atrás → delante no vuelve a skeleton + red.
      ref.keepAlive();
      return ref
          .watch(forumsRepositoryProvider)
          .fetchTopic(key.forumId, key.topicId);
    });

/// Invalida caché del hilo y listados tras cambios de moderación o notificaciones.
void invalidateTopicData(
  WidgetRef ref, {
  required String forumId,
  required String topicId,
  bool refreshActivity = true,
}) {
  ref.invalidate(
    forumTopicProvider(ForumTopicKey(forumId: forumId, topicId: topicId)),
  );
  ref.invalidate(forumTopicsProvider(forumId));
  if (refreshActivity) {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      ref.invalidate(userActivityProvider(userId));
    }
  }
}

/// Registra visita al abrir el hilo. La BD deduplica: 1 por viewer y día.
/// No invalida el topic: evita spinner a pantalla completa en cada apertura.
final topicViewTrackerProvider = FutureProvider.autoDispose
    .family<void, ForumTopicKey>((ref, key) async {
      final viewerId = ref.read(viewerIdProvider);
      final repo = ref.read(forumsRepositoryProvider);
      try {
        await repo.incrementTopicView(key.topicId, viewerId: viewerId);
      } catch (_) {}
    });

final replyUserReactionsProvider = AsyncNotifierProvider.family<
    ReplyUserReactionsNotifier, Map<String, String>, String>(
  ReplyUserReactionsNotifier.new,
);

class ReplyUserReactionsNotifier extends AsyncNotifier<Map<String, String>> {
  ReplyUserReactionsNotifier(this.topicId);

  final String topicId;

  @override
  Future<Map<String, String>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return {};

    final replies = ref.read(topicRepliesStateProvider(topicId)).replies;
    if (replies.isEmpty) return {};

    final repo = ref.read(replyLikesRepositoryProvider);
    if (!repo.isAvailable) return {};

    return repo.fetchUserReactions(
      userId: user.id,
      replyIds: replies.map((r) => r.id).toList(),
    );
  }

  void applyLikePayload(PostgresChangePayload payload) {
    final me = ref.read(currentUserProvider)?.id;
    if (me == null) return;
    final current = Map<String, String>.from(state.asData?.value ?? const {});

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final actor = payload.newRecord['user_id']?.toString();
        final replyId = payload.newRecord['reply_id']?.toString().toLowerCase();
        final reaction = payload.newRecord['reaction'] as String?;
        if (actor != me || replyId == null || replyId.isEmpty) return;
        if (reaction == null || reaction.isEmpty) {
          current.remove(replyId);
        } else {
          current[replyId] = reaction;
        }
        state = AsyncData(current);
        return;
      case PostgresChangeEvent.delete:
        final actor = payload.oldRecord['user_id']?.toString();
        final replyId = payload.oldRecord['reply_id']?.toString().toLowerCase();
        if (actor != me || replyId == null) return;
        current.remove(replyId);
        state = AsyncData(current);
        return;
      case PostgresChangeEvent.all:
        return;
    }
  }
}

final replyReactionCountsProvider = AsyncNotifierProvider.family<
    ReplyReactionCountsNotifier, Map<String, Map<String, int>>, String>(
  ReplyReactionCountsNotifier.new,
);

class ReplyReactionCountsNotifier
    extends AsyncNotifier<Map<String, Map<String, int>>> {
  ReplyReactionCountsNotifier(this.topicId);

  final String topicId;

  /// replyId+userId → emoji (DELETE/UPDATE a veces no traen reaction).
  final Map<String, String> _reactionByActor = {};

  String _actorKey(String replyId, String userId) => '$replyId::$userId';

  @override
  Future<Map<String, Map<String, int>>> build() async {
    final replies = ref.read(topicRepliesStateProvider(topicId)).replies;
    if (replies.isEmpty) return {};

    final repo = ref.read(replyLikesRepositoryProvider);
    if (!repo.isAvailable) return {};

    return repo.fetchReactionCounts(
      replyIds: replies.map((r) => r.id).toList(),
    );
  }

  void applyLikePayload(PostgresChangePayload payload) {
    final current = <String, Map<String, int>>{
      for (final e in (state.asData?.value ?? const {}).entries)
        e.key: Map<String, int>.from(e.value),
    };

    String? replyId;
    String? actor;
    String? oldReaction;
    String? newReaction;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        replyId = payload.newRecord['reply_id']?.toString().toLowerCase();
        actor = payload.newRecord['user_id']?.toString();
        newReaction = payload.newRecord['reaction'] as String?;
        if (replyId != null &&
            actor != null &&
            newReaction != null &&
            newReaction.isNotEmpty) {
          _reactionByActor[_actorKey(replyId, actor)] = newReaction;
        }
        break;
      case PostgresChangeEvent.update:
        replyId = payload.newRecord['reply_id']?.toString().toLowerCase();
        actor = payload.newRecord['user_id']?.toString();
        newReaction = payload.newRecord['reaction'] as String?;
        oldReaction = payload.oldRecord['reaction'] as String?;
        if ((oldReaction == null || oldReaction.isEmpty) &&
            replyId != null &&
            actor != null) {
          oldReaction = _reactionByActor[_actorKey(replyId, actor)];
        }
        if (replyId != null && actor != null) {
          if (newReaction == null || newReaction.isEmpty) {
            _reactionByActor.remove(_actorKey(replyId, actor));
          } else {
            _reactionByActor[_actorKey(replyId, actor)] = newReaction;
          }
        }
        break;
      case PostgresChangeEvent.delete:
        replyId = payload.oldRecord['reply_id']?.toString().toLowerCase();
        actor = payload.oldRecord['user_id']?.toString();
        oldReaction = payload.oldRecord['reaction'] as String?;
        if ((oldReaction == null || oldReaction.isEmpty) &&
            replyId != null &&
            actor != null) {
          oldReaction = _reactionByActor.remove(_actorKey(replyId, actor));
        }
        if ((oldReaction == null || oldReaction.isEmpty) &&
            replyId != null &&
            replyId.isNotEmpty) {
          final existing = current[replyId];
          if (existing != null && existing.length == 1) {
            oldReaction = existing.keys.first;
          }
        }
        break;
      case PostgresChangeEvent.all:
        return;
    }
    if (replyId == null || replyId.isEmpty) return;

    final bucket = Map<String, int>.from(current[replyId] ?? const {});
    if (oldReaction != null && oldReaction.isNotEmpty) {
      final n = (bucket[oldReaction] ?? 0) - 1;
      if (n <= 0) {
        bucket.remove(oldReaction);
      } else {
        bucket[oldReaction] = n;
      }
    }
    if (newReaction != null && newReaction.isNotEmpty) {
      bucket[newReaction] = (bucket[newReaction] ?? 0) + 1;
    }
    if (bucket.isEmpty) {
      current.remove(replyId);
    } else {
      current[replyId] = bucket;
    }
    state = AsyncData(current);
  }
}

final replyLikesRepositoryProvider = Provider<ReplyLikesRepository>((ref) {
  return createReplyLikesRepository();
});

final topicReactionsRepositoryProvider = Provider<TopicReactionsRepository>((
  ref,
) {
  return createTopicReactionsRepository();
});

final topicUserReactionProvider =
    FutureProvider.family<String?, String>((ref, topicId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.watch(topicReactionsRepositoryProvider);
  if (!repo.isAvailable) return null;
  return repo.fetchUserReaction(userId: user.id, topicId: topicId);
});

final topicReactionCountsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, topicId) async {
  final repo = ref.watch(topicReactionsRepositoryProvider);
  if (!repo.isAvailable) return {};
  return repo.fetchReactionCounts(topicId);
});

/// Realtime: reacciones del tema abierto.
final topicReactionsRealtimeProvider = Provider.family<void, String>((
  ref,
  topicId,
) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? debounce;
  void scheduleRefresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 220), () {
      ref.invalidate(topicUserReactionProvider(topicId));
      ref.invalidate(topicReactionCountsProvider(topicId));
    });
  }

  final channel = client
      .channel('topic-reactions-$topicId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_topic_likes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'topic_id',
          value: topicId,
        ),
        callback: (_) => scheduleRefresh(),
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});

/// Realtime: reacciones de replies — parche local por reply_id.
final topicReplyReactionsRealtimeProvider =
    Provider.family<void, String>((ref, topicId) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  final channel = client
      .channel('reply-reactions-$topicId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_reply_likes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'topic_id',
          value: topicId,
        ),
        callback: (payload) {
          ref
              .read(replyReactionCountsProvider(topicId).notifier)
              .applyLikePayload(payload);
          ref
              .read(replyUserReactionsProvider(topicId).notifier)
              .applyLikePayload(payload);
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

/// Realtime: lista de temas del foro — parche local (sin refetch total).
final forumTopicsRealtimeProvider = Provider.family<void, String>((
  ref,
  forumId,
) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? pillarDebounce;
  void schedulePillarRefresh() {
    pillarDebounce?.cancel();
    pillarDebounce = Timer(const Duration(milliseconds: 1200), () {
      ref.invalidate(forumPillarProvider(forumId));
      refreshForumPillarsFromRemote(ref);
    });
  }

  final channel = client
      .channel('forum-topics-$forumId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_topics',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'forum_id',
          value: forumId,
        ),
        callback: (payload) {
          ref
              .read(forumTopicsProvider(forumId).notifier)
              .applyRealtimePayload(payload);
          // Contadores del pilar: solo altas/bajas o cambio de status, no cada view.
          final statusChanged = payload.eventType == PostgresChangeEvent.update &&
              payload.oldRecord['status']?.toString() !=
                  payload.newRecord['status']?.toString();
          if (payload.eventType == PostgresChangeEvent.insert ||
              payload.eventType == PostgresChangeEvent.delete ||
              statusChanged) {
            schedulePillarRefresh();
          }
        },
      )
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Reconexión: una sync completa basta.
          unawaited(
            ref.read(forumTopicsProvider(forumId).notifier).reload(quiet: true),
          );
          schedulePillarRefresh();
        }
      });

  ref.onDispose(() {
    pillarDebounce?.cancel();
    client.removeChannel(channel);
  });
});

/// Realtime: respuestas y metadatos del hilo abierto (comentario, edición, pin…).
final topicThreadRealtimeProvider =
    Provider.family<void, ForumTopicKey>((ref, key) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? topicMetaDebounce;
  void scheduleTopicMetaRefresh() {
    topicMetaDebounce?.cancel();
    topicMetaDebounce = Timer(const Duration(milliseconds: 220), () {
      ref.invalidate(forumTopicProvider(key));
    });
  }

  void applyReplyPayload(PostgresChangePayload payload) {
    final patches = ref.read(topicRepliesLivePatchesProvider.notifier);
    final record = payload.newRecord.isNotEmpty
        ? payload.newRecord
        : payload.oldRecord;
    final replyId = record['id']?.toString();
    if (replyId == null || replyId.isEmpty) {
      refreshTopicRepliesFromRef(ref, key.topicId);
      scheduleTopicMetaRefresh();
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.delete:
        patches.remove(key.topicId, replyId);
        scheduleTopicMetaRefresh();
        break;
      case PostgresChangeEvent.update:
        final deletedRaw = payload.newRecord['deleted_at'];
        if (deletedRaw != null) {
          final deletedAt = DateTime.tryParse(deletedRaw.toString())?.toLocal();
          patches.markDeleted(key.topicId, replyId, deletedAt: deletedAt);
        } else {
          final parsed = ref
              .read(forumsRepositoryProvider)
              .replyFromRealtimeRecord(payload.newRecord);
          if (parsed != null) {
            final existing = ref
                .read(topicRepliesStateProvider(key.topicId))
                .replies
                .where((r) => r.id.toLowerCase() == replyId.toLowerCase())
                .firstOrNull;
            if (existing != null) {
              patches.upsert(
                key.topicId,
                parsed.copyWith(
                  authorHandle: parsed.authorHandle.isNotEmpty
                      ? parsed.authorHandle
                      : existing.authorHandle,
                  authorAvatarUrl:
                      parsed.authorAvatarUrl ?? existing.authorAvatarUrl,
                  authorVerified: existing.authorVerified,
                  authorTrophyPoints: existing.authorTrophyPoints > 0
                      ? existing.authorTrophyPoints
                      : parsed.authorTrophyPoints,
                  timeAgo: existing.timeAgo,
                ),
              );
            } else {
              patches.upsert(key.topicId, parsed);
            }
          } else {
            refreshTopicRepliesFromRef(ref, key.topicId);
          }
        }
        scheduleTopicMetaRefresh();
        break;
      case PostgresChangeEvent.insert:
        final inserted = ref
            .read(forumsRepositoryProvider)
            .replyFromRealtimeRecord(payload.newRecord);
        if (inserted != null) {
          patches.upsert(key.topicId, inserted);
        } else {
          refreshTopicRepliesFromRef(ref, key.topicId);
        }
        scheduleTopicMetaRefresh();
        break;
      case PostgresChangeEvent.all:
        refreshTopicRepliesFromRef(ref, key.topicId);
        scheduleTopicMetaRefresh();
        break;
    }
  }

  final channel = client
      .channel('topic-thread-${key.forumId}-${key.topicId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_replies',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'topic_id',
          value: key.topicId,
        ),
        callback: applyReplyPayload,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_topics',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: key.topicId,
        ),
        callback: (payload) {
          if (payload.eventType == PostgresChangeEvent.delete) {
            ref.invalidate(forumTopicProvider(key));
            ref.read(forumTopicsProvider(key.forumId).notifier).removeById(
                  key.topicId,
                );
            return;
          }
          // Parche lista + meta del hilo abierto (sin refetch de todos los temas).
          ref
              .read(forumTopicsProvider(key.forumId).notifier)
              .applyRealtimePayload(payload);
          scheduleTopicMetaRefresh();
        },
      )
      .subscribe();

  ref.onDispose(() {
    topicMetaDebounce?.cancel();
    client.removeChannel(channel);
  });
});

class ForumTopicKey {
  const ForumTopicKey({required this.forumId, required this.topicId});

  final String forumId;
  final String topicId;

  @override
  bool operator ==(Object other) {
    return other is ForumTopicKey &&
        other.forumId == forumId &&
        other.topicId == topicId;
  }

  @override
  int get hashCode => Object.hash(forumId, topicId);
}

final replyControllerProvider =
    Provider.family<ReplySubmitController, ReplyTarget>((ref, target) {
      return ReplySubmitController(ref, target);
    });

final replyEditControllerProvider =
    Provider.family<ReplyEditController, ReplyEditTarget>((ref, target) {
      return ReplyEditController(ref, target);
    });

class ReplyEditTarget {
  const ReplyEditTarget({
    required this.forumId,
    required this.topicId,
    required this.replyId,
  });

  final String forumId;
  final String topicId;
  final String replyId;
}

class ReplyEditController {
  ReplyEditController(this._ref, this.target);

  final Ref _ref;
  final ReplyEditTarget target;

  Future<void> update(String content) async {
    await _ref
        .read(forumsRepositoryProvider)
        .updateReply(replyId: target.replyId, content: content);
    await _refresh();
  }

  Future<void> updateOfficial({
    required String content,
    required String officialCategory,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    await _ref.read(forumsRepositoryProvider).updateOfficialHermandadPost(
          replyId: target.replyId,
          content: content,
          officialCategory: officialCategory,
          imageUrl: imageUrl,
          clearImage: clearImage,
        );
    await _refresh();
  }

  Future<void> softDelete() async {
    await _ref.read(forumsRepositoryProvider).softDeleteReply(target.replyId);
    await _refresh();
  }

  Future<void> _refresh() async {
    await refreshTopicRepliesFromRef(_ref, target.topicId);
    _ref.invalidate(replyUserReactionsProvider(target.topicId));
    _ref.invalidate(replyReactionCountsProvider(target.topicId));
    _ref.invalidate(
      forumTopicProvider(
        ForumTopicKey(forumId: target.forumId, topicId: target.topicId),
      ),
    );
  }
}

class ReplyTarget {
  const ReplyTarget({
    required this.forumId,
    required this.topicId,
    this.parentReplyId,
    this.isOfficial = false,
    this.officialCategory,
  });

  final String forumId;
  final String topicId;
  final String? parentReplyId;
  final bool isOfficial;
  final String? officialCategory;

  @override
  bool operator ==(Object other) {
    return other is ReplyTarget &&
        other.forumId == forumId &&
        other.topicId == topicId &&
        other.parentReplyId == parentReplyId &&
        other.isOfficial == isOfficial &&
        other.officialCategory == officialCategory;
  }

  @override
  int get hashCode => Object.hash(
    forumId,
    topicId,
    parentReplyId,
    isOfficial,
    officialCategory,
  );
}

class ReplySubmitController {
  ReplySubmitController(this._ref, this.target);

  final Ref _ref;
  final ReplyTarget target;

  Future<void> submit(String content, {String? imageUrl}) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final repo = _ref.read(forumsRepositoryProvider);
    final handle = _ref.read(userHandleProvider);

    await repo.createReply(
      topicId: target.topicId,
      authorId: user.id,
      authorHandle: handle,
      content: content,
      isOfficial: target.isOfficial,
      officialCategory: target.officialCategory,
      parentReplyId: target.parentReplyId,
      imageUrl: imageUrl,
    );

    await refreshTopicRepliesFromRef(_ref, target.topicId);
    _ref.invalidate(replyUserReactionsProvider(target.topicId));
    _ref.invalidate(replyReactionCountsProvider(target.topicId));
    _ref.invalidate(userActivityProvider(user.id));
    _ref.invalidate(
      forumTopicProvider(
        ForumTopicKey(forumId: target.forumId, topicId: target.topicId),
      ),
    );
    _ref.invalidate(forumTopicsProvider(target.forumId));
    _ref.read(notificationsProvider.notifier).refresh();
  }
}

final topicControllerProvider = Provider.family<TopicSubmitController, String>((
  ref,
  forumId,
) {
  return TopicSubmitController(ref, forumId);
});

class TopicSubmitController {
  TopicSubmitController(this._ref, this.forumId);

  final Ref _ref;
  final String forumId;

  Future<ForumTopic> submit({
    required String title,
    required String body,
    String? seasonKey,
    Uint8List? coverBytes,
    String? coverMimeType,
    String? relatedForumId,
  }) async {
    if (forumId == 'hermandades') {
      throw const HermandadTopicsClosedException();
    }

    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const TopicRequiresAuthException();
    }

    if (isNoticiasForum(forumId)) {
      final isAdmin = _ref.read(isAdminProvider);
      final moderated =
          _ref.read(moderatedForumIdsProvider).asData?.value ?? const <String>{};
      if (!canCreateTopicInForum(
        forumId: forumId,
        isAdmin: isAdmin,
        moderatedForumIds: moderated,
      )) {
        throw const NoticiasStaffRequiredException();
      }
    }

    final repo = _ref.read(forumsRepositoryProvider);
    final handle = _ref.read(userHandleProvider);
    final related = isNoticiasForum(forumId) &&
            isValidNoticiasRelatedForum(relatedForumId)
        ? relatedForumId
        : null;

    var topic = await repo.createTopic(
      forumId: forumId,
      authorId: user.id,
      authorHandle: handle,
      title: title,
      body: body,
      seasonKey: seasonKey,
      relatedForumId: related,
    );

    if (coverBytes != null && coverBytes.isNotEmpty) {
      final url = await repo.uploadTopicCover(
        topicId: topic.id,
        bytes: coverBytes,
        mimeType: coverMimeType ?? 'image/jpeg',
      );
      await repo.setTopicCoverAsOwner(
        topicId: topic.id,
        coverImageUrl: url,
      );
      topic = await repo.fetchTopic(forumId, topic.id) ?? topic;
    }

    _ref.invalidate(forumTopicsProvider(forumId));
    _ref.invalidate(userActivityProvider(user.id));
    return topic;
  }
}

class TopicRequiresAuthException implements Exception {
  const TopicRequiresAuthException();
}

class HermandadTopicsClosedException implements Exception {
  const HermandadTopicsClosedException();
}

class NoticiasStaffRequiredException implements Exception {
  const NoticiasStaffRequiredException();
}

final userHandleProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return '@cofrade';

  final meta = user.userMetadata ?? {};
  final raw =
      meta['handle'] as String? ?? user.email?.split('@').first ?? 'cofrade';
  return raw.startsWith('@') ? raw : '@$raw';
});
