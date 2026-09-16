import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import 'reply_likes_repository.dart';

class TopicReactionsRepository {
  TopicReactionsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<String?> fetchUserReaction({
    required String userId,
    required String topicId,
  }) async {
    if (_client == null) return null;

    final row = await _client!
        .from('forum_topic_likes')
        .select('reaction')
        .eq('user_id', userId)
        .eq('topic_id', topicId)
        .maybeSingle();

    return row?['reaction'] as String?;
  }

  Future<Map<String, int>> fetchReactionCounts(String topicId) async {
    if (_client == null) return {};

    try {
      final rows = await _client!.rpc(
        'topic_reaction_counts',
        params: {'p_topic_id': topicId},
      );
      final result = <String, int>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final reaction = map['reaction'] as String? ?? '❤️';
        final count = (map['reaction_count'] as num?)?.toInt() ?? 0;
        if (count > 0) result[reaction] = count;
      }
      return result;
    } catch (_) {
      final rows = await _client!
          .from('forum_topic_likes')
          .select('reaction')
          .eq('topic_id', topicId);
      final tallies = <String, int>{};
      for (final row in rows) {
        final reaction = row['reaction'] as String? ?? '❤️';
        tallies[reaction] = (tallies[reaction] ?? 0) + 1;
      }
      return tallies;
    }
  }

  Future<List<ReplyReactionUser>> fetchReactionUsers(String topicId) async {
    if (_client == null) return [];

    try {
      final rows = await _client!.rpc(
        'topic_reaction_users',
        params: {'p_topic_id': topicId},
      );
      return (rows as List).map((row) {
        final map = row as Map<String, dynamic>;
        return ReplyReactionUser(
          userId: map['user_id'].toString(),
          handle: map['handle'] as String? ?? 'cofrade',
          displayName: map['display_name'] as String? ?? 'Cofrade',
          avatarUrl: map['avatar_url'] as String?,
          reaction: map['reaction'] as String? ?? '❤️',
          reactedAt: map['reacted_at'] != null
              ? DateTime.tryParse(map['reacted_at'].toString())
              : null,
        );
      }).toList();
    } catch (_) {
      final rows = await _client!
          .from('forum_topic_likes')
          .select(
            'user_id, reaction, created_at, profiles(handle, display_name, avatar_url)',
          )
          .eq('topic_id', topicId)
          .order('created_at', ascending: false);
      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>? ?? {};
        return ReplyReactionUser(
          userId: row['user_id'].toString(),
          handle: profile['handle'] as String? ?? 'cofrade',
          displayName: profile['display_name'] as String? ?? 'Cofrade',
          avatarUrl: profile['avatar_url'] as String?,
          reaction: row['reaction'] as String? ?? '❤️',
          reactedAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null,
        );
      }).toList();
    }
  }

  /// `null` [reaction] quita la reacción del usuario.
  Future<void> setReaction({
    required String userId,
    required String topicId,
    required String? reaction,
  }) async {
    if (_client == null) throw const TopicReactionsUnavailableException();

    if (reaction == null) {
      await _client!
          .from('forum_topic_likes')
          .delete()
          .eq('user_id', userId)
          .eq('topic_id', topicId);
      return;
    }

    await _client!.from('forum_topic_likes').upsert(
      {
        'user_id': userId,
        'topic_id': topicId,
        'reaction': reaction,
      },
      onConflict: 'topic_id,user_id',
    );
  }
}

class TopicReactionsUnavailableException implements Exception {
  const TopicReactionsUnavailableException();
}

TopicReactionsRepository createTopicReactionsRepository() {
  return TopicReactionsRepository(client: SupabaseBootstrap.client);
}
