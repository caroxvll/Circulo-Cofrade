import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class ReplyLikesRepository {
  ReplyLikesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<Set<String>> fetchLikedReplyIds({
    required String userId,
    required List<String> replyIds,
  }) async {
    if (_client == null || replyIds.isEmpty) return {};

    final rows = await _client!
        .from('forum_reply_likes')
        .select('reply_id')
        .eq('user_id', userId)
        .inFilter('reply_id', replyIds);

    return rows.map((r) => r['reply_id'].toString().toLowerCase()).toSet();
  }

  Future<bool> toggleLike({
    required String userId,
    required String replyId,
    required bool currentlyLiked,
  }) async {
    if (_client == null) throw const ReplyLikesUnavailableException();

    if (currentlyLiked) {
      await _client!
          .from('forum_reply_likes')
          .delete()
          .eq('user_id', userId)
          .eq('reply_id', replyId);
      return false;
    }

    await _client!.from('forum_reply_likes').insert({
      'user_id': userId,
      'reply_id': replyId,
    });
    return true;
  }
}

class ReplyLikesUnavailableException implements Exception {
  const ReplyLikesUnavailableException();
}

ReplyLikesRepository createReplyLikesRepository() {
  return ReplyLikesRepository(client: SupabaseBootstrap.client);
}
