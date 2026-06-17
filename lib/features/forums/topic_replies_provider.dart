import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/forum.dart';
import '../moderation/moderation_provider.dart';
import 'data/forums_repository.dart';
import 'forums_provider.dart';

const topicRepliesPageSize = 30;

class ReplyPagination {
  const ReplyPagination({
    this.extra = const [],
    this.dbOffset = 0,
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<ForumReply> extra;
  final int dbOffset;
  final bool hasMore;
  final bool loadingMore;

  ReplyPagination copyWith({
    List<ForumReply>? extra,
    int? dbOffset,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ReplyPagination(
      extra: extra ?? this.extra,
      dbOffset: dbOffset ?? this.dbOffset,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

class TopicRepliesState {
  const TopicRepliesState({
    required this.replies,
    required this.hasMore,
    this.isLoadingMore = false,
    this.isLoading = false,
  });

  final List<ForumReply> replies;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isLoading;
}

class TopicRepliesPaginationMap extends Notifier<Map<String, ReplyPagination>> {
  @override
  Map<String, ReplyPagination> build() => {};

  ReplyPagination of(String topicId) =>
      state[topicId] ?? const ReplyPagination();

  void reset(String topicId) {
    state = {...state, topicId: const ReplyPagination()};
  }

  void patch(String topicId, ReplyPagination value) {
    state = {...state, topicId: value};
  }
}

final topicRepliesPaginationProvider =
    NotifierProvider<TopicRepliesPaginationMap, Map<String, ReplyPagination>>(
  TopicRepliesPaginationMap.new,
);

final topicRepliesFirstPageProvider =
    FutureProvider.autoDispose.family<List<ForumReply>, String>(
  (ref, topicId) async {
    final hidden = await ref.watch(hiddenForumAuthorIdsProvider.future);
    final batch = await ref.read(forumsRepositoryProvider).fetchReplies(
          topicId,
          limit: topicRepliesPageSize,
          offset: 0,
        );
    ref.read(topicRepliesPaginationProvider.notifier).patch(
          topicId,
          ReplyPagination(
            dbOffset: batch.length,
            hasMore: batch.length == topicRepliesPageSize,
          ),
        );
    return batch
        .where((r) => r.authorId == null || !hidden.contains(r.authorId))
        .toList();
  },
);

final topicRepliesStateProvider =
    Provider.autoDispose.family<TopicRepliesState, String>((ref, topicId) {
  final firstAsync = ref.watch(topicRepliesFirstPageProvider(topicId));
  final pagination = ref.watch(topicRepliesPaginationProvider)[topicId] ??
      const ReplyPagination();

  return firstAsync.when(
    loading: () => const TopicRepliesState(
      replies: [],
      hasMore: true,
      isLoading: true,
    ),
    error: (_, __) => TopicRepliesState(
      replies: pagination.extra,
      hasMore: false,
    ),
    data: (first) => TopicRepliesState(
      replies: [...first, ...pagination.extra],
      hasMore: pagination.hasMore,
      isLoadingMore: pagination.loadingMore,
    ),
  );
});

Future<void> refreshTopicReplies(WidgetRef ref, String topicId) async {
  ref.read(topicRepliesPaginationProvider.notifier).reset(topicId);
  ref.invalidate(topicRepliesFirstPageProvider(topicId));
}

Future<void> loadMoreTopicReplies(WidgetRef ref, String topicId) async {
  final paginationNotifier = ref.read(topicRepliesPaginationProvider.notifier);
  var pagination = paginationNotifier.of(topicId);
  if (pagination.loadingMore || !pagination.hasMore) return;

  pagination = pagination.copyWith(loadingMore: true);
  paginationNotifier.patch(topicId, pagination);

  try {
    final hidden = ref.read(hiddenForumAuthorIdsProvider).value ?? {};
    final batch = await ref.read(forumsRepositoryProvider).fetchReplies(
          topicId,
          limit: topicRepliesPageSize,
          offset: pagination.dbOffset,
        );
    final filtered = batch
        .where((r) => r.authorId == null || !hidden.contains(r.authorId))
        .toList();

    paginationNotifier.patch(
      topicId,
      pagination.copyWith(
        extra: [...pagination.extra, ...filtered],
        dbOffset: pagination.dbOffset + batch.length,
        hasMore: batch.length == topicRepliesPageSize,
        loadingMore: false,
      ),
    );
  } catch (_) {
    paginationNotifier.patch(
      topicId,
      pagination.copyWith(loadingMore: false),
    );
  }
}

Future<void> refreshTopicRepliesFromRef(Ref ref, String topicId) async {
  ref.read(topicRepliesPaginationProvider.notifier).reset(topicId);
  ref.invalidate(topicRepliesFirstPageProvider(topicId));
}
