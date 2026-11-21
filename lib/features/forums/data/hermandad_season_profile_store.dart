import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/hermandad_season_profile.dart';

class HermandadSeasonProfileStore {
  HermandadSeasonProfileStore({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<HermandadSeasonProfile> fetch(String topicId) async {
    final client = _client;
    if (client == null) return HermandadSeasonProfile.defaults;
    try {
      final row = await client
          .from('hermandad_season_profile')
          .select()
          .eq('topic_id', topicId)
          .maybeSingle();
      if (row == null) return HermandadSeasonProfile.defaults;
      return HermandadSeasonProfile.fromRow(row);
    } catch (_) {
      return HermandadSeasonProfile.defaults;
    }
  }

  Future<Map<String, HermandadSeasonProfile>> fetchAll() async {
    final client = _client;
    if (client == null) return const {};
    try {
      final rows = await client.from('hermandad_season_profile').select();
      return {
        for (final row in rows)
          if (row['topic_id'] is String)
            row['topic_id'] as String: HermandadSeasonProfile.fromRow(row),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> save(String topicId, HermandadSeasonProfile profile) async {
    final client = _client;
    if (client == null) return;
    await client.from('hermandad_season_profile').upsert(profile.toDb(topicId));
  }
}
