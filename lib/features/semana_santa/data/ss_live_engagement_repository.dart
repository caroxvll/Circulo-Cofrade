import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class SsLiveReply {
  const SsLiveReply({
    required this.id,
    required this.updateId,
    required this.userId,
    required this.authorHandle,
    required this.message,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  final String id;
  final String updateId;
  final String userId;
  final String authorHandle;
  final String? authorAvatarUrl;
  final String message;
  final DateTime createdAt;
}

class SsLiveEngagementSnapshot {
  const SsLiveEngagementSnapshot({
    this.reactionCounts = const {},
    this.userReactions = const {},
    this.replyCounts = const {},
  });

  /// updateId → emoji → count
  final Map<String, Map<String, int>> reactionCounts;

  /// updateId → emoji del usuario actual
  final Map<String, String> userReactions;

  /// updateId → nº respuestas
  final Map<String, int> replyCounts;

  Map<String, int> countsFor(String updateId) =>
      reactionCounts[updateId] ?? const {};

  String? userReactionFor(String updateId) => userReactions[updateId];

  int replyCountFor(String updateId) => replyCounts[updateId] ?? 0;
}

class SsLiveEngagementRepository {
  SsLiveEngagementRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<SsLiveEngagementSnapshot> fetchSnapshot({
    required List<String> updateIds,
    String? userId,
  }) async {
    final client = _client;
    if (client == null || updateIds.isEmpty) {
      return const SsLiveEngagementSnapshot();
    }

    final reactionCounts = <String, Map<String, int>>{};
    final userReactions = <String, String>{};
    final replyCounts = <String, int>{};

    try {
      final rows = await client.rpc(
        'ss_live_reaction_counts',
        params: {'p_update_ids': updateIds},
      );
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final id = map['update_id'].toString();
        final reaction = map['reaction'] as String? ?? '❤️';
        final count = (map['reaction_count'] as num?)?.toInt() ?? 0;
        if (count <= 0) continue;
        reactionCounts.putIfAbsent(id, () => {})[reaction] = count;
      }
    } catch (_) {
      final rows = await client
          .from('ss_live_update_likes')
          .select('update_id, reaction')
          .inFilter('update_id', updateIds);
      for (final row in rows) {
        final id = row['update_id'].toString();
        final reaction = row['reaction'] as String? ?? '❤️';
        final bucket = reactionCounts.putIfAbsent(id, () => {});
        bucket[reaction] = (bucket[reaction] ?? 0) + 1;
      }
    }

    try {
      final rows = await client.rpc(
        'ss_live_reply_counts',
        params: {'p_update_ids': updateIds},
      );
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final id = map['update_id'].toString();
        final count = (map['reply_count'] as num?)?.toInt() ?? 0;
        if (count > 0) replyCounts[id] = count;
      }
    } catch (_) {
      final rows = await client
          .from('ss_live_update_replies')
          .select('update_id')
          .inFilter('update_id', updateIds);
      for (final row in rows) {
        final id = row['update_id'].toString();
        replyCounts[id] = (replyCounts[id] ?? 0) + 1;
      }
    }

    if (userId != null && userId.isNotEmpty) {
      final rows = await client
          .from('ss_live_update_likes')
          .select('update_id, reaction')
          .eq('user_id', userId)
          .inFilter('update_id', updateIds);
      for (final row in rows) {
        final reaction = row['reaction'] as String?;
        if (reaction == null || reaction.isEmpty) continue;
        userReactions[row['update_id'].toString()] = reaction;
      }
    }

    return SsLiveEngagementSnapshot(
      reactionCounts: reactionCounts,
      userReactions: userReactions,
      replyCounts: replyCounts,
    );
  }

  Future<void> setReaction({
    required String userId,
    required String updateId,
    required String? reaction,
  }) async {
    final client = _client;
    if (client == null) return;

    if (reaction == null) {
      await client
          .from('ss_live_update_likes')
          .delete()
          .eq('user_id', userId)
          .eq('update_id', updateId);
      return;
    }

    await client.from('ss_live_update_likes').upsert(
      {
        'user_id': userId,
        'update_id': updateId,
        'reaction': reaction,
      },
      onConflict: 'update_id,user_id',
    );
  }

  Future<List<SsLiveReply>> fetchReplies(String updateId) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('ss_live_update_replies')
        .select('*, profiles!user_id(handle, avatar_url)')
        .eq('update_id', updateId)
        .order('created_at', ascending: true)
        .limit(60);

    return rows.map(_replyFromRow).toList();
  }

  Future<SsLiveReply> postReply({
    required String userId,
    required String updateId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Vacío');
    }
    final client = _client;
    if (client == null) {
      return SsLiveReply(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        updateId: updateId,
        userId: userId,
        authorHandle: '@cofrade',
        message: trimmed,
        createdAt: DateTime.now(),
      );
    }

    final row = await client
        .from('ss_live_update_replies')
        .insert({
          'user_id': userId,
          'update_id': updateId,
          'message': trimmed,
        })
        .select('*, profiles!user_id(handle, avatar_url)')
        .single();

    return _replyFromRow(row);
  }

  SsLiveReply _replyFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final handleRaw = profile?['handle'] as String? ?? 'cofrade';
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    final avatar = (profile?['avatar_url'] as String?)?.trim();
    return SsLiveReply(
      id: row['id'] as String,
      updateId: row['update_id'] as String,
      userId: row['user_id'] as String,
      authorHandle: handle,
      authorAvatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}

SsLiveEngagementRepository createSsLiveEngagementRepository() {
  return SsLiveEngagementRepository(client: SupabaseBootstrap.client);
}
