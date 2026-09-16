import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/forum.dart';
import '../moderation/moderation_provider.dart';
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

/// Parches locales de realtime: UI al instante; el refetch confirma después.
class TopicRepliesLivePatch {
  const TopicRepliesLivePatch({
    this.upserts = const {},
    this.removedIds = const {},
    this.softDeletedAt = const {},
  });

  final Map<String, ForumReply> upserts;
  final Set<String> removedIds;
  final Map<String, DateTime> softDeletedAt;
}

class TopicRepliesLivePatchesMap
    extends Notifier<Map<String, TopicRepliesLivePatch>> {
  @override
  Map<String, TopicRepliesLivePatch> build() => {};

  TopicRepliesLivePatch of(String topicId) =>
      state[topicId] ?? const TopicRepliesLivePatch();

  void clear(String topicId) {
    if (!state.containsKey(topicId)) return;
    final next = {...state}..remove(topicId);
    state = next;
  }

  void upsert(String topicId, ForumReply reply) {
    final current = of(topicId);
    final id = reply.id.toLowerCase();
    final soft = {...current.softDeletedAt};
    if (reply.deletedAt != null) {
      soft[id] = reply.deletedAt!;
    } else {
      soft.remove(id);
    }
    state = {
      ...state,
      topicId: TopicRepliesLivePatch(
        upserts: {...current.upserts, id: reply},
        removedIds: {...current.removedIds}..remove(id),
        softDeletedAt: soft,
      ),
    };
  }

  void markDeleted(String topicId, String replyId, {DateTime? deletedAt}) {
    final id = replyId.toLowerCase();
    final current = of(topicId);
    state = {
      ...state,
      topicId: TopicRepliesLivePatch(
        upserts: current.upserts,
        removedIds: {...current.removedIds}..remove(id),
        softDeletedAt: {
          ...current.softDeletedAt,
          id: deletedAt ?? DateTime.now(),
        },
      ),
    };
  }

  void remove(String topicId, String replyId) {
    final id = replyId.toLowerCase();
    final current = of(topicId);
    final upserts = {...current.upserts}..remove(id);
    final soft = {...current.softDeletedAt}..remove(id);
    state = {
      ...state,
      topicId: TopicRepliesLivePatch(
        upserts: upserts,
        removedIds: {...current.removedIds, id},
        softDeletedAt: soft,
      ),
    };
  }
}

final topicRepliesLivePatchesProvider = NotifierProvider<
    TopicRepliesLivePatchesMap, Map<String, TopicRepliesLivePatch>>(
  TopicRepliesLivePatchesMap.new,
);

List<ForumReply> applyLivePatches(
  List<ForumReply> replies,
  TopicRepliesLivePatch patch,
) {
  if (patch.upserts.isEmpty &&
      patch.removedIds.isEmpty &&
      patch.softDeletedAt.isEmpty) {
    return replies;
  }

  final byId = <String, ForumReply>{
    for (final r in replies) r.id.toLowerCase(): r,
  };

  for (final entry in patch.upserts.entries) {
    final previous = byId[entry.key];
    final incoming = entry.value;
    if (previous == null) {
      byId[entry.key] = incoming;
      continue;
    }
    byId[entry.key] = previous.copyWith(
      content: incoming.content.isNotEmpty ? incoming.content : null,
      authorHandle:
          incoming.authorHandle.isNotEmpty ? incoming.authorHandle : null,
      deletedAt: incoming.deletedAt ?? previous.deletedAt,
      editedAt: incoming.editedAt ?? previous.editedAt,
      parentReplyId: incoming.parentReplyId ?? previous.parentReplyId,
      imageUrl: incoming.imageUrl ?? previous.imageUrl,
    );
  }

  for (final entry in patch.softDeletedAt.entries) {
    final previous = byId[entry.key];
    if (previous == null || previous.isDeleted) continue;
    byId[entry.key] = previous.copyWith(deletedAt: entry.value);
  }

  for (final id in patch.removedIds) {
    byId.remove(id);
  }

  final seen = <String>{};
  final ordered = <ForumReply>[];
  for (final r in replies) {
    final id = r.id.toLowerCase();
    if (patch.removedIds.contains(id)) continue;
    final next = byId[id];
    if (next == null) continue;
    ordered.add(next);
    seen.add(id);
  }
  for (final id in patch.upserts.keys) {
    if (seen.contains(id) || patch.removedIds.contains(id)) continue;
    final next = byId[id];
    if (next != null) ordered.add(next);
  }
  return ordered;
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
    ref.read(topicRepliesLivePatchesProvider.notifier).clear(topicId);
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
  final live =
      ref.watch(topicRepliesLivePatchesProvider)[topicId] ??
      const TopicRepliesLivePatch();

  return firstAsync.when(
    loading: () => TopicRepliesState(
      replies: applyLivePatches(const [], live),
      hasMore: true,
      isLoading: true,
    ),
    error: (_, _) => TopicRepliesState(
      replies: applyLivePatches(pagination.extra, live),
      hasMore: false,
    ),
    data: (first) => TopicRepliesState(
      replies: applyLivePatches([...first, ...pagination.extra], live),
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
