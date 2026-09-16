import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/hermandad_scheduled_post.dart';
import '../auth/auth_provider.dart';
import 'data/hermandad_scheduled_posts_repository.dart';
import 'forums_provider.dart';
import 'topic_replies_provider.dart';

final hermandadScheduledPostsRepositoryProvider =
    Provider<HermandadScheduledPostsRepository>((ref) {
  return createHermandadScheduledPostsRepository();
});

final myHermandadPendingPostsProvider =
    FutureProvider.autoDispose<HermandadPendingPosts>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) {
    return const HermandadPendingPosts(drafts: [], scheduled: []);
  }

  await ref
      .read(hermandadScheduledPostsRepositoryProvider)
      .publishDuePosts();

  return ref
      .read(hermandadScheduledPostsRepositoryProvider)
      .fetchMyPending(authorId: userId);
});

/// Compatibilidad con código que solo necesitaba programadas.
final myHermandadScheduledPostsProvider =
    FutureProvider.autoDispose<List<HermandadScheduledPost>>((ref) async {
  final pending = await ref.watch(myHermandadPendingPostsProvider.future);
  return pending.scheduled;
});

Future<void> refreshHermandadPendingPostsFromRef(Ref ref) async {
  ref.invalidate(myHermandadPendingPostsProvider);
}

Future<int> publishDueHermandadPostsFromRef(Ref ref) async {
  final count = await ref
      .read(hermandadScheduledPostsRepositoryProvider)
      .publishDuePosts();
  if (count > 0) {
    ref.invalidate(myHermandadPendingPostsProvider);
    ref.invalidate(forumTopicsProvider('hermandades'));
  }
  return count;
}

class HermandadScheduledPostController {
  HermandadScheduledPostController(this._ref);

  final Ref _ref;

  Future<void> schedule({
    required String topicId,
    required String forumId,
    required String content,
    required String officialCategory,
    required DateTime scheduledAt,
    String? imageUrl,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final handle = _ref.read(userHandleProvider);
    await _ref.read(hermandadScheduledPostsRepositoryProvider).createScheduled(
          authorId: user.id,
          authorHandle: handle,
          topicId: topicId,
          content: content,
          officialCategory: officialCategory,
          scheduledAt: scheduledAt,
          imageUrl: imageUrl,
        );

    await _refresh(forumId);
  }

  Future<void> saveDraft({
    required String topicId,
    required String forumId,
    required String content,
    required String officialCategory,
    String? imageUrl,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final handle = _ref.read(userHandleProvider);
    await _ref.read(hermandadScheduledPostsRepositoryProvider).createDraft(
          authorId: user.id,
          authorHandle: handle,
          topicId: topicId,
          content: content,
          officialCategory: officialCategory,
          imageUrl: imageUrl,
        );

    await _refresh(forumId);
  }

  Future<void> updateScheduled({
    required String id,
    required String forumId,
    required String content,
    required String officialCategory,
    required DateTime scheduledAt,
    String? imageUrl,
  }) async {
    await _ref.read(hermandadScheduledPostsRepositoryProvider).updateScheduled(
          id: id,
          content: content,
          officialCategory: officialCategory,
          scheduledAt: scheduledAt,
          imageUrl: imageUrl,
        );

    await _refresh(forumId);
  }

  Future<void> updateDraft({
    required String id,
    required String forumId,
    required String content,
    required String officialCategory,
    String? imageUrl,
  }) async {
    await _ref.read(hermandadScheduledPostsRepositoryProvider).updateDraft(
          id: id,
          content: content,
          officialCategory: officialCategory,
          imageUrl: imageUrl,
        );

    await _refresh(forumId);
  }

  Future<void> scheduleDraft({
    required String id,
    required String forumId,
    required String content,
    required String officialCategory,
    required DateTime scheduledAt,
    String? imageUrl,
  }) async {
    await _ref.read(hermandadScheduledPostsRepositoryProvider).scheduleDraft(
          id: id,
          content: content,
          officialCategory: officialCategory,
          scheduledAt: scheduledAt,
          imageUrl: imageUrl,
        );

    await _refresh(forumId);
  }

  Future<void> cancel(String id) async {
    await _ref
        .read(hermandadScheduledPostsRepositoryProvider)
        .cancelPending(id);
    await refreshHermandadPendingPostsFromRef(_ref);
  }

  Future<void> deleteDraft(String id) async {
    await _ref
        .read(hermandadScheduledPostsRepositoryProvider)
        .deleteDraft(id);
    await refreshHermandadPendingPostsFromRef(_ref);
  }

  Future<void> _refresh(String forumId) async {
    await refreshHermandadPendingPostsFromRef(_ref);
    _ref.invalidate(forumTopicsProvider(forumId));
  }
}

final hermandadScheduledPostControllerProvider =
    Provider<HermandadScheduledPostController>((ref) {
  return HermandadScheduledPostController(ref);
});

Future<void> ensureHermandadDuePostsPublished(
  WidgetRef ref, {
  required String topicId,
  required String forumId,
}) async {
  final count = await ref
      .read(hermandadScheduledPostsRepositoryProvider)
      .publishDuePosts();
  if (count > 0) {
    ref.invalidate(myHermandadPendingPostsProvider);
    ref.invalidate(forumTopicsProvider('hermandades'));
    ref.read(topicRepliesPaginationProvider.notifier).reset(topicId);
    ref.invalidate(topicRepliesFirstPageProvider(topicId));
    ref.invalidate(
      forumTopicProvider(
        ForumTopicKey(forumId: forumId, topicId: topicId),
      ),
    );
  }
}
