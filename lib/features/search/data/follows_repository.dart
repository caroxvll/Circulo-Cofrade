import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../shared/models/followed_topic.dart';

class FollowsRepository {
  FollowsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<Set<String>> fetchFollowedHashtags(String userId) async {
    if (_client == null) return {};

    final rows = await _client!
        .from('follows')
        .select('target_id')
        .eq('follower_id', userId)
        .eq('target_type', 'hashtag');

    return rows
        .map((r) => r['target_id'] as String)
        .toSet();
  }

  Future<bool> isFollowingHashtag({
    required String userId,
    required String hashtag,
  }) async {
    if (_client == null) return false;

    final row = await _client!
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('target_type', 'hashtag')
        .eq('target_id', hashtag)
        .maybeSingle();

    return row != null;
  }

  Future<void> toggleHashtag({
    required String userId,
    required String hashtag,
    required bool follow,
  }) async {
    if (_client == null) {
      throw const FollowsUnavailableException();
    }

    if (follow) {
      await _client!.from('follows').upsert({
        'follower_id': userId,
        'target_type': 'hashtag',
        'target_id': hashtag,
      });
    } else {
      await _client!
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('target_type', 'hashtag')
          .eq('target_id', hashtag);
    }
  }

  Future<Set<String>> fetchFollowedProfiles(String userId) async {
    if (_client == null) return {};

    final rows = await _client!
        .from('follows')
        .select('target_id')
        .eq('follower_id', userId)
        .eq('target_type', 'profile');

    return rows.map((r) => r['target_id'] as String).toSet();
  }

  /// Cuentas que siguen a [profileId] (requiere policy follows_see_followers.sql).
  Future<List<String>> fetchFollowerProfileIds(String profileId) async {
    if (_client == null) return const [];

    final rows = await _client!
        .from('follows')
        .select('follower_id, created_at')
        .eq('target_type', 'profile')
        .eq('target_id', profileId)
        .order('created_at', ascending: false);

    return rows.map((r) => r['follower_id'] as String).toList();
  }

  Future<bool> isFollowingProfile({
    required String userId,
    required String profileId,
  }) async {
    if (_client == null) return false;

    final row = await _client!
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('target_type', 'profile')
        .eq('target_id', profileId)
        .maybeSingle();

    return row != null;
  }

  Future<void> toggleProfile({
    required String userId,
    required String profileId,
    required bool follow,
  }) async {
    if (_client == null) {
      throw const FollowsUnavailableException();
    }

    if (follow) {
      await _client!.from('follows').upsert({
        'follower_id': userId,
        'target_type': 'profile',
        'target_id': profileId,
      });
    } else {
      await _client!
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('target_type', 'profile')
          .eq('target_id', profileId);
    }
  }

  Future<Set<String>> fetchFollowedTopics(String userId) async {
    if (_client == null) return {};

    final rows = await _client!
        .from('follows')
        .select('target_id')
        .eq('follower_id', userId)
        .eq('target_type', 'topic');

    return rows.map((r) => r['target_id'] as String).toSet();
  }

  Future<bool> isFollowingTopic({
    required String userId,
    required String topicId,
  }) async {
    if (_client == null) return false;

    final row = await _client!
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('target_type', 'topic')
        .eq('target_id', topicId)
        .maybeSingle();

    return row != null;
  }

  Future<List<String>?> fetchTopicFollowNotifyCategories({
    required String userId,
    required String topicId,
  }) async {
    if (_client == null) return null;

    final row = await _client!
        .from('follows')
        .select('notify_official_categories')
        .eq('follower_id', userId)
        .eq('target_type', 'topic')
        .eq('target_id', topicId)
        .maybeSingle();

    if (row == null) return null;
    final raw = row['notify_official_categories'];
    if (raw == null) return null;
    return List<String>.from(raw as List);
  }

  Future<void> updateTopicFollowNotifyCategories({
    required String userId,
    required String topicId,
    required List<String>? notifyOfficialCategories,
  }) async {
    if (_client == null) {
      throw const FollowsUnavailableException();
    }

    await _client!
        .from('follows')
        .update({'notify_official_categories': notifyOfficialCategories})
        .eq('follower_id', userId)
        .eq('target_type', 'topic')
        .eq('target_id', topicId);
  }

  Future<bool> isFollowingForum({
    required String userId,
    required String forumId,
  }) async {
    if (_client == null) return false;

    final row = await _client!
        .from('follows')
        .select('id')
        .eq('follower_id', userId)
        .eq('target_type', 'forum')
        .eq('target_id', forumId)
        .maybeSingle();

    return row != null;
  }

  Future<void> toggleForum({
    required String userId,
    required String forumId,
    required bool follow,
  }) async {
    if (_client == null) {
      throw const FollowsUnavailableException();
    }

    if (follow) {
      await _client!.from('follows').upsert({
        'follower_id': userId,
        'target_type': 'forum',
        'target_id': forumId,
      });
    } else {
      await _client!
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('target_type', 'forum')
          .eq('target_id', forumId);
    }
  }

  Future<void> toggleTopic({
    required String userId,
    required String topicId,
    required bool follow,
    List<String>? notifyOfficialCategories,
  }) async {
    if (_client == null) {
      throw const FollowsUnavailableException();
    }

    if (follow) {
      final payload = <String, dynamic>{
        'follower_id': userId,
        'target_type': 'topic',
        'target_id': topicId,
      };
      if (notifyOfficialCategories != null) {
        payload['notify_official_categories'] = notifyOfficialCategories;
      }
      await _client!.from('follows').upsert(payload);
    } else {
      await _client!
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('target_type', 'topic')
          .eq('target_id', topicId);
    }
  }

  Future<List<FollowedTopic>> fetchFollowedTopicsWithDetails(
    String userId,
  ) async {
    if (_client == null) return [];

    final rows = await _client!
        .from('follows')
        .select('target_id, created_at, notify_official_categories')
        .eq('follower_id', userId)
        .eq('target_type', 'topic')
        .order('created_at', ascending: false);

    if (rows.isEmpty) return [];

    final topicIds = rows.map((r) => r['target_id'] as String).toList();
    final topicRows = await _client!
        .from('forum_topics')
        .select('id, forum_id, title, excerpt')
        .inFilter('id', topicIds);

    final byId = <String, Map<String, dynamic>>{
      for (final row in topicRows) row['id'] as String: row,
    };

    final topics = <FollowedTopic>[];
    for (final row in rows) {
      final topicId = row['target_id'] as String;
      final topic = byId[topicId];
      if (topic == null) continue;

      topics.add(
        FollowedTopic(
          topicId: topicId,
          forumId: topic['forum_id'] as String,
          title: topic['title'] as String,
          preview: topic['excerpt'] as String? ?? '',
          notifyOfficialCategories: _parseNotifyCategories(
            row['notify_official_categories'],
          ),
        ),
      );
    }
    return topics;
  }

  List<String>? _parseNotifyCategories(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    return List<String>.from(raw);
  }
}

class FollowsUnavailableException implements Exception {
  const FollowsUnavailableException();
}

FollowsRepository createFollowsRepository() {
  return FollowsRepository(client: SupabaseBootstrap.client);
}
