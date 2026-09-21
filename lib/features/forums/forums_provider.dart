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

final forumTopicsProvider = FutureProvider.family<List<ForumTopic>, String>((
  ref,
  forumId,
) async {
  return ref.watch(forumsRepositoryProvider).fetchTopics(forumId);
});

final forumTopicProvider = FutureProvider.autoDispose
    .family<ForumTopic?, ForumTopicKey>((ref, key) async {
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
final topicViewTrackerProvider = FutureProvider.autoDispose
    .family<void, ForumTopicKey>((ref, key) async {
      final viewerId = ref.read(viewerIdProvider);
      final repo = ref.read(forumsRepositoryProvider);
      try {
        await repo.incrementTopicView(key.topicId, viewerId: viewerId);
        // Solo el tema abierto: no refetch de toda la lista del foro.
        ref.invalidate(forumTopicProvider(key));
      } catch (_) {}
    });

final replyUserReactionsProvider =
    FutureProvider.family<Map<String, String>, String>((ref, topicId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repliesState = ref.watch(topicRepliesStateProvider(topicId));
  final replies = repliesState.replies;
  if (replies.isEmpty) return {};

  final repo = ref.read(replyLikesRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchUserReactions(
    userId: user.id,
    replyIds: replies.map((r) => r.id).toList(),
  );
});

final replyReactionCountsProvider =
    FutureProvider.family<Map<String, Map<String, int>>, String>((
  ref,
  topicId,
) async {
  final repliesState = ref.watch(topicRepliesStateProvider(topicId));
  final replies = repliesState.replies;
  if (replies.isEmpty) return {};

  final repo = ref.read(replyLikesRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchReactionCounts(
    replyIds: replies.map((r) => r.id).toList(),
  );
});

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
        callback: (_) {
          ref.invalidate(topicUserReactionProvider(topicId));
          ref.invalidate(topicReactionCountsProvider(topicId));
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

/// Realtime: sincroniza reacciones entre pestañas/dispositivos en un hilo.
final topicReplyReactionsRealtimeProvider =
    Provider.family<void, String>((ref, topicId) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  final replyIds = ref.watch(
    topicRepliesStateProvider(topicId).select(
      (state) => state.replies.map((r) => r.id.toLowerCase()).toSet(),
    ),
  );
  if (replyIds.isEmpty) return;

  final channel = client
      .channel('reply-reactions-$topicId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_reply_likes',
        callback: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          final replyId = record['reply_id']?.toString().toLowerCase();
          if (replyId == null || !replyIds.contains(replyId)) return;
          ref.invalidate(replyUserReactionsProvider(topicId));
          ref.invalidate(replyReactionCountsProvider(topicId));
        },
      )
      .subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
  });
});

/// Realtime: lista de temas del foro (altas, publicaciones, cierres, contadores).
final forumTopicsRealtimeProvider = Provider.family<void, String>((
  ref,
  forumId,
) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? debounce;
  void scheduleRefresh({bool immediate = false}) {
    debounce?.cancel();
    if (immediate) {
      ref.invalidate(forumTopicsProvider(forumId));
      return;
    }
    debounce = Timer(const Duration(milliseconds: 80), () {
      ref.invalidate(forumTopicsProvider(forumId));
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
          // Altas/bajas y cambios de status (p. ej. pending→published) al instante.
          final immediate = payload.eventType == PostgresChangeEvent.delete ||
              payload.eventType == PostgresChangeEvent.insert ||
              payload.eventType == PostgresChangeEvent.update;
          scheduleRefresh(immediate: immediate);
          // Contadores de la tarjeta del foro (temas / msgs).
          ref.invalidate(forumPillarProvider(forumId));
          refreshForumPillarsFromRemote(ref);
        },
      )
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          // Al conectar/reconectar, sincroniza por si se publicó desde el admin.
          scheduleRefresh(immediate: true);
          ref.invalidate(forumPillarProvider(forumId));
          refreshForumPillarsFromRemote(ref);
        }
      });

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});

/// Realtime: respuestas y metadatos del hilo abierto (comentario, edición, pin…).
final topicThreadRealtimeProvider =
    Provider.family<void, ForumTopicKey>((ref, key) {
  final client = SupabaseBootstrap.client;
  if (client == null) return;

  Timer? debounce;
  void scheduleFullRefresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 180), () {
      refreshTopicRepliesFromRef(ref, key.topicId);
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
      scheduleFullRefresh();
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.delete:
        patches.remove(key.topicId, replyId);
        ref.invalidate(forumTopicProvider(key));
        break;
      case PostgresChangeEvent.update:
        final deletedRaw = payload.newRecord['deleted_at'];
        if (deletedRaw != null) {
          final deletedAt = DateTime.tryParse(deletedRaw.toString())?.toLocal();
          patches.markDeleted(key.topicId, replyId, deletedAt: deletedAt);
        } else {
          final content = payload.newRecord['content']?.toString();
          final handle = payload.newRecord['author_handle']?.toString();
          if (content != null || handle != null) {
            final existing = ref
                .read(topicRepliesStateProvider(key.topicId))
                .replies
                .where((r) => r.id.toLowerCase() == replyId.toLowerCase())
                .firstOrNull;
            if (existing != null) {
              patches.upsert(
                key.topicId,
                existing.copyWith(
                  content: content,
                  authorHandle: handle,
                  editedAt: DateTime.tryParse(
                        payload.newRecord['edited_at']?.toString() ?? '',
                      )?.toLocal() ??
                      existing.editedAt,
                ),
              );
            }
          }
        }
        ref.invalidate(forumTopicProvider(key));
        scheduleFullRefresh();
        break;
      case PostgresChangeEvent.insert:
        scheduleFullRefresh();
        break;
      case PostgresChangeEvent.all:
        scheduleFullRefresh();
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
          debounce?.cancel();
          if (payload.eventType == PostgresChangeEvent.delete) {
            ref.invalidate(forumTopicProvider(key));
            ref.invalidate(forumTopicsProvider(key.forumId));
            return;
          }
          debounce = Timer(const Duration(milliseconds: 80), () {
            ref.invalidate(forumTopicProvider(key));
            ref.invalidate(forumTopicsProvider(key.forumId));
          });
        },
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
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
