import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import 'mock_search.dart';

class TrendsRepository {
  TrendsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemote => _client != null;

  Future<List<SearchTrend>> fetchTrends({int limit = 8}) async {
    if (_client == null) return mockSearchTrends;

    final rows = await _client!.rpc(
      'fetch_trending_hashtags',
      params: {'p_limit': limit},
    );

    return [
      for (final row in rows as List)
        _trendFromRow(row as Map<String, dynamic>),
    ];
  }

  SearchTrend _trendFromRow(Map<String, dynamic> row) {
    final hashtagRaw = row['hashtag'] as String;
    final hashtag =
        hashtagRaw.startsWith('#') ? hashtagRaw : '#$hashtagRaw';
    return SearchTrend(
      id: trendIdFromHashtag(hashtag),
      hashtag: hashtag,
      postCount: (row['post_count'] as num?)?.toInt() ?? 0,
      avatarIcon: iconForHashtag(hashtag),
    );
  }
}

String trendIdFromHashtag(String hashtag) {
  return hashtag
      .replaceAll('#', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

IconData iconForHashtag(String hashtag) {
  const known = <String, IconData>{
    '#viernessanto': Icons.church,
    '#marchascofradas': Icons.music_note,
    '#costaleros': Icons.workspace_premium_outlined,
    '#glorias': Icons.wb_sunny_outlined,
    '#procesiones': Icons.church,
    '#ensayos': Icons.music_note,
    '#igualas': Icons.groups_outlined,
    '#conciertos': Icons.music_note,
  };

  final icon = known[hashtag.toLowerCase()];
  if (icon != null) return icon;

  const fallback = <IconData>[
    Icons.tag,
    Icons.church,
    Icons.music_note,
    Icons.wb_sunny_outlined,
    Icons.workspace_premium_outlined,
  ];
  return fallback[hashtag.hashCode.abs() % fallback.length];
}

TrendsRepository createTrendsRepository() {
  return TrendsRepository(client: SupabaseBootstrap.client);
}
