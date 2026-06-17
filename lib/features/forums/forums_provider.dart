import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/forum.dart';
import '../auth/auth_provider.dart';
import '../moderation/moderation_provider.dart';
import '../notifications/notifications_provider.dart';
import '../profile/profile_provider.dart';
import 'data/forums_repository.dart';
import 'data/reply_likes_repository.dart';
import 'topic_replies_provider.dart';
import 'viewer_id_provider.dart';

final forumsRepositoryProvider = Provider<ForumsRepository>((ref) {
  return createForumsRepository();
});

final forumPillarsProvider = FutureProvider<List<ForumCategory>>((ref) async {
  return ref.watch(forumsRepositoryProvider).fetchPillars();
});

final forumPillarProvider =
    FutureProvider.family<ForumCategory?, String>((ref, forumId) async {
  return ref.watch(forumsRepositoryProvider).fetchPillar(forumId);
});

final forumTopicsProvider =
    FutureProvider.family<List<ForumTopic>, String>((ref, forumId) async {
  return ref.watch(forumsRepositoryProvider).fetchTopics(forumId);
});

final forumTopicProvider =
    FutureProvider.autoDispose.family<ForumTopic?, ForumTopicKey>(
  (ref, key) async {
    return ref.watch(forumsRepositoryProvider).fetchTopic(
          key.forumId,
          key.topicId,
        );
  },
);

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
final topicViewTrackerProvider =
    FutureProvider.autoDispose.family<void, ForumTopicKey>((ref, key) async {
  final viewerId = ref.read(viewerIdProvider);
  final repo = ref.read(forumsRepositoryProvider);
  try {
    await repo.incrementTopicView(key.topicId, viewerId: viewerId);
    ref.invalidate(forumTopicProvider(key));
    ref.invalidate(forumTopicsProvider(key.forumId));
  } catch (_) {}
});

final likedReplyIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, topicId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final repliesState = ref.watch(topicRepliesStateProvider(topicId));
  final replies = repliesState.replies;
  if (replies.isEmpty) return {};

  final repo = ref.read(replyLikesRepositoryProvider);
  if (!repo.isAvailable) return {};

  return repo.fetchLikedReplyIds(
    userId: user.id,
    replyIds: replies.map((r) => r.id).toList(),
  );
});

final replyLikesRepositoryProvider = Provider<ReplyLikesRepository>((ref) {
  return createReplyLikesRepository();
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
    await _ref.read(forumsRepositoryProvider).updateReply(
          replyId: target.replyId,
          content: content,
        );
    await refreshTopicRepliesFromRef(_ref, target.topicId);
    _ref.invalidate(likedReplyIdsProvider(target.topicId));
    _ref.invalidate(
      forumTopicProvider(
        ForumTopicKey(forumId: target.forumId, topicId: target.topicId),
      ),
    );
  }

  Future<void> softDelete() async {
    await _ref.read(forumsRepositoryProvider).softDeleteReply(target.replyId);
    await refreshTopicRepliesFromRef(_ref, target.topicId);
    _ref.invalidate(likedReplyIdsProvider(target.topicId));
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
  });

  final String forumId;
  final String topicId;
  final String? parentReplyId;

  @override
  bool operator ==(Object other) {
    return other is ReplyTarget &&
        other.forumId == forumId &&
        other.topicId == topicId &&
        other.parentReplyId == parentReplyId;
  }

  @override
  int get hashCode => Object.hash(forumId, topicId, parentReplyId);
}

class ReplySubmitController {
  ReplySubmitController(this._ref, this.target);

  final Ref _ref;
  final ReplyTarget target;

  Future<void> submit(String content) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final repo = _ref.read(forumsRepositoryProvider);
    final handle = _ref.read(userHandleProvider);

    await repo.createReply(
      topicId: target.topicId,
      authorId: user.id,
      authorHandle: handle,
      content: content,
      parentReplyId: target.parentReplyId,
    );

    await refreshTopicRepliesFromRef(_ref, target.topicId);
    _ref.invalidate(likedReplyIdsProvider(target.topicId));
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

final topicControllerProvider =
    Provider.family<TopicSubmitController, String>((ref, forumId) {
  return TopicSubmitController(ref, forumId);
});

class TopicSubmitController {
  TopicSubmitController(this._ref, this.forumId);

  final Ref _ref;
  final String forumId;

  Future<ForumTopic> submit({
    required String title,
    required String body,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const TopicRequiresAuthException();
    }

    final repo = _ref.read(forumsRepositoryProvider);
    final handle = _ref.read(userHandleProvider);

    final topic = await repo.createTopic(
      forumId: forumId,
      authorId: user.id,
      authorHandle: handle,
      title: title,
      body: body,
    );

    _ref.invalidate(forumTopicsProvider(forumId));
    _ref.invalidate(userActivityProvider(user.id));
    return topic;
  }
}

class TopicRequiresAuthException implements Exception {
  const TopicRequiresAuthException();
}

final userHandleProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return '@cofrade';

  final meta = user.userMetadata ?? {};
  final raw = meta['handle'] as String? ?? user.email?.split('@').first ?? 'cofrade';
  return raw.startsWith('@') ? raw : '@$raw';
});
