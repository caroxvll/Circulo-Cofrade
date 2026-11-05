import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/followed_topic.dart';
import '../../shared/models/forum.dart';
import '../search/follows_provider.dart';
import 'forums_provider.dart';
import 'utils/hermandad_board_display.dart';
import 'utils/official_post_categories.dart';

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

class HermandadDigest {
  const HermandadDigest({
    required this.board,
    required this.hermandadName,
    required this.sections,
    this.processionDay,
  });

  final FollowedTopic board;
  final String hermandadName;
  final String? processionDay;
  final List<HermandadFeedItem> sections;
}

/// Lo último de cada sección, agrupado por hermandad seguida.
final followedHermandadDigestsProvider =
    FutureProvider.autoDispose<List<HermandadDigest>>((ref) async {
  ref.keepAlive();
  final boards = await ref.watch(followedHermandadBoardsProvider.future);
  if (boards.isEmpty) return [];

  final order = {
    for (var i = 0; i < officialPostCategories.length; i++)
      officialPostCategories[i].value: i,
  };
  final replies = await ref
      .watch(forumsRepositoryProvider)
      .fetchLatestOfficialBySection([
        for (final board in boards) board.topicId,
      ]);
  final byTopic = <String, List<ForumReply>>{};
  for (final reply in replies) {
    byTopic.putIfAbsent(reply.topicId, () => []).add(reply);
  }

  return [
    for (final board in boards)
      HermandadDigest(
        board: board,
        hermandadName: parseHermandadTopicTitle(board.title).hermandadName,
        processionDay: parseHermandadTopicTitle(board.title).processionDay,
        sections: _sectionsFor(board, byTopic[board.topicId] ?? const [], order),
      ),
  ];
});

List<HermandadFeedItem> _sectionsFor(
  FollowedTopic board,
  List<ForumReply> replies,
  Map<String, int> order,
) {
  final sorted = [...replies]..sort((a, b) {
    final aOrder = order[a.officialCategory] ?? 9;
    final bOrder = order[b.officialCategory] ?? 9;
    return aOrder.compareTo(bOrder);
  });
  final parsed = parseHermandadTopicTitle(board.title);
  return [
    for (final reply in sorted)
      HermandadFeedItem(
        reply: reply,
        board: board,
        hermandadName: parsed.hermandadName,
        processionDay: parsed.processionDay,
      ),
  ];
}

/// Feed cronológico de publicaciones oficiales de las hermandades seguidas.
final followedHermandadFeedProvider =
    FutureProvider.autoDispose<List<HermandadFeedItem>>((ref) async {
  ref.keepAlive();
  final digests = await ref.watch(followedHermandadDigestsProvider.future);
  return [for (final digest in digests) ...digest.sections];
});
