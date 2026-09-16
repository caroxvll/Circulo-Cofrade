import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../models/ss_live_update.dart';
import 'mock_ss_live_updates.dart';

class SsLiveUpdateRateLimitedException implements Exception {
  const SsLiveUpdateRateLimitedException();
}

class SsLiveUpdatesRepository {
  SsLiveUpdatesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _minSecondsBetweenPosts = 45;
  static const _feedWindow = Duration(hours: 12);

  Future<List<SsLiveUpdate>> fetchFeed({
    SsLiveUpdateKind? kind,
    int limit = 80,
  }) async {
    final client = _client;
    if (client == null) {
      return mockSsLiveUpdates(kind: kind);
    }

    final since = DateTime.now().toUtc().subtract(_feedWindow);
    var query = client
        .from('ss_live_updates')
        .select('*, profiles!user_id(handle, avatar_url)')
        .gte('created_at', since.toIso8601String());

    if (kind != null) {
      query = query.eq('kind', kind.dbValue);
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);

    return (rows as List)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<SsLiveUpdate> postUpdate({
    required String userId,
    required SsLiveUpdateKind kind,
    required String message,
    String? hermandadLabel,
    String? placeLabel,
    double? latitude,
    double? longitude,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(message, 'message', 'El mensaje no puede estar vacío');
    }

    final client = _client;
    if (client == null) {
      final lastAt = mockSsLastPostAt(userId);
      if (lastAt != null &&
          DateTime.now().difference(lastAt).inSeconds < _minSecondsBetweenPosts) {
        throw const SsLiveUpdateRateLimitedException();
      }
      return addMockSsLiveUpdate(
        userId: userId,
        authorHandle: '@cofrade',
        kind: kind,
        message: trimmed,
        hermandadLabel: hermandadLabel,
        placeLabel: placeLabel,
        latitude: latitude,
        longitude: longitude,
      );
    }

    final lastRows = await client
        .from('ss_live_updates')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);

    if (lastRows.isNotEmpty) {
      final lastAt = DateTime.parse(lastRows.first['created_at'] as String);
      if (DateTime.now().toUtc().difference(lastAt.toUtc()).inSeconds <
          _minSecondsBetweenPosts) {
        throw const SsLiveUpdateRateLimitedException();
      }
    }

    final row = await client
        .from('ss_live_updates')
        .insert({
          'user_id': userId,
          'kind': kind.dbValue,
          'hermandad_label': hermandadLabel?.trim() ?? '',
          'message': trimmed,
          'place_label': placeLabel?.trim() ?? '',
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        })
        .select('*, profiles!user_id(handle, avatar_url)')
        .single();

    return _fromRow(row);
  }

  SsLiveUpdate _fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final handleRaw = profile?['handle'] as String? ?? 'cofrade';
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    final avatar = (profile?['avatar_url'] as String?)?.trim();
    final hermandad = (row['hermandad_label'] as String?)?.trim() ?? '';
    final place = (row['place_label'] as String?)?.trim() ?? '';

    return SsLiveUpdate(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      authorHandle: handle,
      authorAvatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      kind: SsLiveUpdateKind.fromDb(row['kind'] as String?),
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      hermandadLabel: hermandad.isEmpty ? null : hermandad,
      placeLabel: place.isEmpty ? null : place,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }
}

SsLiveUpdatesRepository createSsLiveUpdatesRepository() {
  return SsLiveUpdatesRepository(client: SupabaseBootstrap.client);
}
