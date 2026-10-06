import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/followed_topic.dart';
import '../../shared/models/forum.dart';
import '../search/follows_provider.dart';
import 'forums_provider.dart';
import 'utils/hermandad_board_display.dart';

/// Tablones de hermandad que el usuario sigue.
final followedHermandadBoardsProvider =
    FutureProvider<List<FollowedTopic>>((ref) async {
  final topics = await ref.watch(followedTopicsDetailsProvider.future);
  return topics.where((t) => t.isHermandadBoard).toList();
});

class HermandadFeedItem {
  const HermandadFeedItem({
    required this.reply,
    required this.board,
    required this.hermandadName,
    this.processionDay,
  });

  final ForumReply reply;
  final FollowedTopic board;
  final String hermandadName;
  final String? processionDay;
}

/// Feed cronológico de publicaciones oficiales de las hermandades seguidas.
final followedHermandadFeedProvider =
    FutureProvider.autoDispose<List<HermandadFeedItem>>((ref) async {
  final boards = await ref.watch(followedHermandadBoardsProvider.future);
  if (boards.isEmpty) return [];

  final byTopic = {for (final b in boards) b.topicId: b};
  final replies = await ref
      .watch(forumsRepositoryProvider)
      .fetchOfficialRepliesForTopics(byTopic.keys.toList());

  final items = <HermandadFeedItem>[];
  for (final reply in replies) {
    final board = byTopic[reply.topicId];
    if (board == null) continue;
    final parsed = parseHermandadTopicTitle(board.title);
    items.add(
      HermandadFeedItem(
        reply: reply,
        board: board,
        hermandadName: parsed.hermandadName,
        processionDay: parsed.processionDay,
      ),
    );
  }
  return items;
});
