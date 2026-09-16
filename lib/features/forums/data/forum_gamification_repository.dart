import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../constants/cofrade_trophies.dart';
import '../utils/cofrade_gamification.dart';

class ForumGamificationRepository {
  ForumGamificationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<CofradeGamificationSnapshot> fetchSnapshot(String userId) async {
    if (_client == null) {
      return CofradeGamificationSnapshot.empty;
    }

    final trophyRows = await _client!
        .from('profile_trophies')
        .select('trophy_id, unlocked_at')
        .eq('user_id', userId)
        .order('unlocked_at', ascending: false);

    final unlockedIds = [
      for (final row in trophyRows)
        row['trophy_id'] as String,
    ];

    final profileRow = await _client!
        .from('profiles')
        .select('trophy_points')
        .eq('id', userId)
        .maybeSingle();

    final points = profileRow?['trophy_points'] as int? ??
        trophyPointsFromIds(unlockedIds);

    CofradeForumStats stats = const CofradeForumStats();
    try {
      stats = await _fetchStats(userId);
    } catch (_) {
      // Tabla/RPC aún no desplegados en el entorno local.
    }

    return CofradeGamificationSnapshot(
      trophyPoints: points,
      unlockedTrophyIds: unlockedIds.toSet(),
      stats: stats,
    );
  }

  Future<CofradeForumStats> _fetchStats(String userId) async {
    final reactions = await _client!.rpc(
      'forum_reactions_received',
      params: {'p_user_id': userId},
    );
    final validReplies = await _client!.rpc(
      'forum_valid_reply_count',
      params: {'p_user_id': userId},
    );
    final topicsCreated = await _client!.rpc(
      'forum_topics_created_count',
      params: {'p_user_id': userId},
    );
    final topicViews = await _client!.rpc(
      'forum_topic_views_total',
      params: {'p_user_id': userId},
    );
    final maxTopicFollowers = await _client!.rpc(
      'forum_max_topic_followers',
      params: {'p_user_id': userId},
    );
    final maxHashtagFollowers = await _client!.rpc(
      'forum_max_hashtag_followers',
      params: {'p_user_id': userId},
    );
    final profileRow = await _client!
        .from('profiles')
        .select('follower_count')
        .eq('id', userId)
        .maybeSingle();

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    return CofradeForumStats(
      validReplyCount: asInt(validReplies),
      topicsCreatedCount: asInt(topicsCreated),
      topicViewsTotal: asInt(topicViews),
      reactionsReceived: asInt(reactions),
      followerCount: profileRow?['follower_count'] as int? ?? 0,
      maxHashtagFollowers: asInt(maxHashtagFollowers),
      maxTopicFollowers: asInt(maxTopicFollowers),
    );
  }
}

final class CofradeGamificationSnapshot {
  const CofradeGamificationSnapshot({
    required this.trophyPoints,
    required this.unlockedTrophyIds,
    required this.stats,
  });

  static const empty = CofradeGamificationSnapshot(
    trophyPoints: 0,
    unlockedTrophyIds: {},
    stats: CofradeForumStats(),
  );

  final int trophyPoints;
  final Set<String> unlockedTrophyIds;
  final CofradeForumStats stats;

  String get rankTitle => cofradeRankTitleForPoints(trophyPoints);

  List<CofradeTrophy> get unlockedTrophies => [
        for (final trophy in CofradeTrophies.all)
          if (unlockedTrophyIds.contains(trophy.id)) trophy,
      ];

  List<CofradeTrophyProgress> get nearestLockedTrophies =>
      nearestTrophyProgress(stats, limit: 3);
}

ForumGamificationRepository createForumGamificationRepository() {
  return ForumGamificationRepository(client: SupabaseBootstrap.client);
}
