import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class ReplyReactionUser {
  const ReplyReactionUser({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.reaction,
    this.avatarUrl,
    this.reactedAt,
  });

  final String userId;
  final String handle;
  final String displayName;
  final String reaction;
  final String? avatarUrl;
  final DateTime? reactedAt;

  String get displayHandle =>
      handle.startsWith('@') ? handle : '@$handle';
}

class ReplyLikesRepository {
  ReplyLikesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<Map<String, String>> fetchUserReactions({
    required String userId,
    required List<String> replyIds,
  }) async {
    if (_client == null || replyIds.isEmpty) return {};

    final rows = await _client!
        .from('forum_reply_likes')
        .select('reply_id, reaction')
        .eq('user_id', userId)
        .inFilter('reply_id', replyIds);

    return {
      for (final row in rows)
        row['reply_id'].toString().toLowerCase():
            row['reaction'] as String? ?? '❤️',
    };
  }

  Future<Map<String, Map<String, int>>> fetchReactionCounts({
    required List<String> replyIds,
  }) async {
    if (_client == null || replyIds.isEmpty) return {};

    try {
      final rows = await _client!.rpc(
        'reply_reaction_counts',
        params: {'p_reply_ids': replyIds},
      );
      return _parseReactionCountRows(rows as List);
    } catch (_) {
      final rows = await _client!
          .from('forum_reply_likes')
          .select('reply_id, reaction')
          .inFilter('reply_id', replyIds);
      final tallies = <String, Map<String, int>>{};
      for (final row in rows) {
        final replyId = row['reply_id'].toString().toLowerCase();
        final reaction = row['reaction'] as String? ?? '❤️';
        tallies.putIfAbsent(replyId, () => {});
        tallies[replyId]![reaction] = (tallies[replyId]![reaction] ?? 0) + 1;
      }
      return tallies;
    }
  }

  Future<List<ReplyReactionUser>> fetchReactionUsers({
    required String replyId,
  }) async {
    if (_client == null) return [];

    try {
      final rows = await _client!.rpc(
        'reply_reaction_users',
        params: {'p_reply_id': replyId},
      );
      return _parseReactionUserRows(rows as List);
    } catch (_) {
      final rows = await _client!
          .from('forum_reply_likes')
          .select('user_id, reaction, created_at, profiles(handle, display_name, avatar_url)')
          .eq('reply_id', replyId)
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

  List<ReplyReactionUser> _parseReactionUserRows(List rows) {
    return rows.map((row) {
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
  }

  Map<String, Map<String, int>> _parseReactionCountRows(List rows) {
    final result = <String, Map<String, int>>{};
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final replyId = map['reply_id'].toString().toLowerCase();
      final reaction = map['reaction'] as String? ?? '❤️';
      final count = (map['reaction_count'] as num?)?.toInt() ?? 0;
      result.putIfAbsent(replyId, () => {});
      result[replyId]![reaction] = count;
    }
    return result;
  }

  /// `null` [reaction] quita la reacción del usuario.
  Future<void> setReaction({
    required String userId,
    required String replyId,
    required String? reaction,
  }) async {
    if (_client == null) throw const ReplyLikesUnavailableException();

    if (reaction == null) {
      await _client!
          .from('forum_reply_likes')
          .delete()
          .eq('user_id', userId)
          .eq('reply_id', replyId);
      return;
    }

    // Sin .select().single(): evita fallos PGRST116 si RLS no devuelve la fila.
    await _client!.from('forum_reply_likes').upsert(
      {
        'user_id': userId,
        'reply_id': replyId,
        'reaction': reaction,
      },
      onConflict: 'reply_id,user_id',
    );
  }
}

String replyReactionSaveErrorMessage(Object error) {
  if (error is PostgrestException) {
    if (error.code == '23514') {
      return 'Falta ejecutar reply_reactions_emoji.sql en Supabase '
          '(la base de datos aún no acepta emojis).';
    }
    // Columna existe en Postgres pero PostgREST aún no la ve.
    if (error.code == 'PGRST204') {
      return 'Supabase no ha recargado el esquema. En SQL Editor ejecuta: '
          "notify pgrst, 'reload schema';";
    }
    if (error.code == '42703') {
      final parts = <String>[
        error.message,
        if (error.details != null) '${error.details}',
        if (error.hint != null) '${error.hint}',
      ];
      final detail = parts
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(' · ');
      return detail.isEmpty
          ? 'Error 42703 (columna inexistente en un trigger/política). '
              'Ejecuta reply_reactions_mobile_fix.sql'
          : '[42703] $detail';
    }
    final message = error.message.trim();
    if (message.isNotEmpty) {
      return '${error.code != null ? '[${error.code}] ' : ''}$message';
    }
  }
  return 'No se pudo guardar la reacción.';
}

class ReplyLikesUnavailableException implements Exception {
  const ReplyLikesUnavailableException();
}

/// Cancelación de UI (login / email / suspendido): rollback optimistic sin snack de error de red.
class ReplyReactionCancelled implements Exception {
  const ReplyReactionCancelled();
}

ReplyLikesRepository createReplyLikesRepository() {
  return ReplyLikesRepository(client: SupabaseBootstrap.client);
}
