import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class ModerationRepository {
  ModerationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<Set<String>> fetchBlockedUserIds(String blockerId) async {
    if (_client == null) return {};

    final rows = await _client!
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', blockerId);

    return rows.map((r) => r['blocked_id'].toString()).toSet();
  }

  Future<List<Map<String, dynamic>>> fetchBlockedProfileRows(
    String blockerId,
  ) async {
    if (_client == null) return [];

    final rows = await _client!
        .from('blocks')
        .select('blocked_id, created_at, profiles!blocked_id(id, handle, display_name, avatar_url, bio)')
        .eq('blocker_id', blockerId)
        .order('created_at', ascending: false);

    return rows.cast<Map<String, dynamic>>();
  }

  Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    if (_client == null) return false;

    final row = await _client!
        .from('blocks')
        .select('blocker_id')
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId)
        .maybeSingle();

    return row != null;
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    if (_client == null) throw const ModerationUnavailableException();

    await _client!.from('blocks').upsert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    if (_client == null) throw const ModerationUnavailableException();

    await _client!
        .from('blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  Future<void> reportProfile({
    required String reporterId,
    required String profileId,
    required String reason,
    String details = '',
  }) async {
    await reportContent(
      reporterId: reporterId,
      targetType: 'profile',
      targetId: profileId,
      reason: reason,
      details: details,
    );
  }

  Future<void> reportContent({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    if (_client == null) throw const ModerationUnavailableException();

    await _client!.from('reports').insert({
      'reporter_id': reporterId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'details': details,
    });
  }

  Future<Set<String>> fetchSuspendedUserIds() async {
    if (_client == null) return {};

    final rows = await _client!
        .from('profiles')
        .select('id')
        .not('suspended_at', 'is', null);

    return rows.map((r) => r['id'].toString()).toSet();
  }
}

class ModerationUnavailableException implements Exception {
  const ModerationUnavailableException();
}

ModerationRepository createModerationRepository() {
  return ModerationRepository(client: SupabaseBootstrap.client);
}
