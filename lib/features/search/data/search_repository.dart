import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/forum.dart';
import '../models/search_results.dart';
import '../../calendar/data/calendar_repository.dart';
import 'mock_search.dart';

class SearchRepository {
  SearchRepository({
    SupabaseClient? client,
    CalendarRepository? calendarRepository,
  })  : _client = client,
        _calendarRepository =
            calendarRepository ?? CalendarRepository(client: client);

  final SupabaseClient? _client;
  final CalendarRepository _calendarRepository;

  static const _profileAuthorSelect =
      'profiles!author_id(avatar_url, suspended_at)';

  bool get isRemote => _client != null;

  Future<SearchResults> search(String rawQuery) async {
    final query = _sanitize(rawQuery);
    if (query.isEmpty) return SearchResults.empty;

    if (_client == null) {
      return SearchResults(
        topics: searchTopics(query),
        profiles: searchProfiles(query),
        events: await _calendarRepository.searchEvents(query),
      );
    }

    final pattern = '%$query%';

    final topicRows = await _client!
        .from('forum_topics')
        .select('*, $_profileAuthorSelect')
        .eq('status', 'published')
        .or('title.ilike.$pattern,excerpt.ilike.$pattern,body.ilike.$pattern')
        .order('created_at', ascending: false)
        .limit(25);

    final replyTopicIds = await _topicIdsFromReplyMatches(pattern);
    final existingIds = topicRows.map((r) => r['id'] as String).toSet();
    final extraIds = replyTopicIds.difference(existingIds).toList();

    final extraTopicRows = extraIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client!
            .from('forum_topics')
            .select('*, $_profileAuthorSelect')
            .eq('status', 'published')
            .inFilter('id', extraIds)
            .order('created_at', ascending: false);

    final handleQuery = query.replaceAll('@', '');
    final profileRows = await _client!
        .from('profiles')
        .select('id, handle, display_name, avatar_url, bio')
        .isFilter('suspended_at', null)
        .or(
          'handle.ilike.$handleQuery%,display_name.ilike.$pattern,bio.ilike.$pattern',
        )
        .order('display_name')
        .limit(12);

    final events = await _calendarRepository.searchEvents(query);

    final allTopicRows = [...topicRows, ...extraTopicRows];

    return SearchResults(
      topics: allTopicRows
          .where((row) => !_isAuthorSuspended(row))
          .map(_topicFromRow)
          .toList(),
      profiles: [
        for (final row in profileRows) _profileFromRow(row),
      ],
      events: events,
    );
  }

  String _sanitize(String raw) {
    return raw.replaceAll('%', '').replaceAll('_', '').trim();
  }

  Future<Set<String>> _topicIdsFromReplyMatches(String pattern) async {
    final rows = await _client!
        .from('forum_replies')
        .select('topic_id')
        .ilike('content', pattern)
        .limit(50);

    return rows.map((r) => r['topic_id'] as String).toSet();
  }

  ForumTopic _topicFromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.parse(row['created_at'] as String);
    return ForumTopic(
      id: row['id'] as String,
      forumId: row['forum_id'] as String,
      title: row['title'] as String,
      excerpt: row['excerpt'] as String,
      body: normalizeStoredText(row['body'] as String),
      authorHandle: row['author_handle'] as String,
      timeAgo: formatTimeAgo(createdAt),
      commentCount: row['comment_count'] as int? ?? 0,
      viewCount: row['view_count'] as int? ?? 0,
      isResolved: row['is_resolved'] as bool? ?? false,
      authorId: row['author_id'] as String?,
      authorAvatarUrl: _avatarUrlFromRow(row),
      status: TopicStatus.published,
    );
  }

  SearchProfileHit _profileFromRow(Map<String, dynamic> row) {
    final handleRaw = row['handle'] as String;
    final handle = handleRaw.startsWith('@') ? handleRaw : '@$handleRaw';
    return SearchProfileHit(
      id: row['id'] as String,
      handle: handle,
      displayName: row['display_name'] as String? ?? handleRaw,
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String? ?? '',
    );
  }

  String? _avatarUrlFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    if (profile is Map<String, dynamic>) {
      return profile['avatar_url'] as String?;
    }
    return null;
  }

  bool _isAuthorSuspended(Map<String, dynamic> row) {
    final profile = row['profiles'];
    if (profile is Map<String, dynamic>) {
      return profile['suspended_at'] != null;
    }
    return false;
  }
}

SearchRepository createSearchRepository() {
  return SearchRepository(client: SupabaseBootstrap.client);
}
