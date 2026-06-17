import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/forum.dart';
import 'forum_icons.dart';
import 'mock_forums.dart';
import 'reply_moderation_exception.dart';

class ForumsRepository {
  ForumsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  /// PostgREST exige el FK explícito tras añadir `parent_reply_id` en respuestas.
  static const _profileAuthorSelect =
      'profiles!author_id(avatar_url, suspended_at)';

  bool get _useRemote => _client != null;

  Future<List<ForumCategory>> fetchPillars() async {
    if (!_useRemote) return visibleForumCategories;

    final rows = await _client!
        .from('forum_pillars')
        .select()
        .order('sort_order', ascending: true);

    return rows.map(_pillarFromRow).toList();
  }

  Future<ForumCategory?> fetchPillar(String id) async {
    if (!_useRemote) return forumById(id);

    final row = await _client!
        .from('forum_pillars')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return _pillarFromRow(row);
  }

  Future<List<ForumTopic>> fetchTopics(String forumId) async {
    if (!_useRemote) return topicsForForum(forumId);

    final rows = await _client!
        .from('forum_topics')
        .select('*, $_profileAuthorSelect')
        .eq('forum_id', forumId)
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return rows
        .where((row) => !_isAuthorSuspended(row))
        .map(_topicFromRow)
        .toList();
  }

  Future<ForumTopic?> fetchTopic(String forumId, String topicId) async {
    if (!_useRemote) return topicById(forumId, topicId);

    final row = await _client!
        .from('forum_topics')
        .select('*, $_profileAuthorSelect')
        .eq('forum_id', forumId)
        .eq('id', topicId)
        .maybeSingle();

    if (row == null) return null;
    return _topicFromRow(row);
  }

  Future<List<ForumReply>> fetchReplies(
    String topicId, {
    int limit = 30,
    int offset = 0,
  }) async {
    if (!_useRemote) return repliesForTopic(topicId);

    final rows = await _client!
        .from('forum_replies')
        .select('*, $_profileAuthorSelect')
        .eq('topic_id', topicId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows
        .where((row) => !_isAuthorSuspended(row))
        .map(_replyFromRow)
        .toList();
  }

  Future<void> incrementTopicView(
    String topicId, {
    required String viewerId,
  }) async {
    if (!_useRemote) return;

    await _client!.rpc('increment_topic_view', params: {
      'p_topic_id': topicId,
      'p_viewer_id': viewerId,
    });
  }

  Future<ForumTopic> createTopic({
    required String forumId,
    required String authorId,
    required String authorHandle,
    required String title,
    required String body,
  }) async {
    if (!_useRemote) {
      throw const ForumsRemoteUnavailableException();
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    final excerpt = trimmedBody.length > 160
        ? '${trimmedBody.substring(0, 157)}...'
        : trimmedBody;

    final row = await _client!
        .from('forum_topics')
        .insert({
          'id': _generateTopicId(trimmedTitle),
          'forum_id': forumId,
          'author_id': authorId,
          'author_handle': authorHandle,
          'title': trimmedTitle,
          'excerpt': excerpt,
          'body': trimmedBody,
          'status': 'pending',
        })
        .select('*, $_profileAuthorSelect')
        .single();

    return _topicFromRow(row);
  }

  Future<ForumReply> createReply({
    required String topicId,
    required String authorId,
    required String authorHandle,
    required String content,
    String? parentReplyId,
  }) async {
    if (!_useRemote) {
      throw const ForumsRemoteUnavailableException();
    }

    final row = await _client!
        .from('forum_replies')
        .insert({
          'topic_id': topicId,
          'author_id': authorId,
          'author_handle': authorHandle,
          'content': content.trim(),
          if (parentReplyId != null) 'parent_reply_id': parentReplyId,
        })
        .select('*, $_profileAuthorSelect')
        .single();

    return _replyFromRow(row);
  }

  Future<void> updateReply({
    required String replyId,
    required String content,
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    try {
      await _client!.rpc('update_own_forum_reply', params: {
        'p_reply_id': replyId,
        'p_content': content.trim(),
      });
    } on PostgrestException catch (e) {
      throw ReplyModerationException.fromPostgrestMessage(e.message) ??
          const ReplyModerationException(ReplyModerationException.forbidden);
    }
  }

  Future<void> softDeleteReply(String replyId) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    try {
      await _client!.rpc('soft_delete_forum_reply', params: {
        'p_reply_id': replyId,
      });
    } on PostgrestException catch (e) {
      throw ReplyModerationException.fromPostgrestMessage(e.message) ??
          const ReplyModerationException(ReplyModerationException.forbidden);
    }
  }

  ForumCategory _pillarFromRow(Map<String, dynamic> row) {
    final enabled = row['is_enabled'] as bool? ?? true;
    final lastActivityRaw = row['last_activity_at'] as String?;
    final lastActivity = lastActivityRaw != null
        ? DateTime.parse(lastActivityRaw).toLocal()
        : null;

    return ForumCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      icon: forumIconFromKey(row['icon_key'] as String?),
      headerIcon: forumIconFromKey(row['icon_key'] as String?),
      sortOrder: row['sort_order'] as int? ?? 0,
      topicCount: row['topic_count'] as int? ?? 0,
      messageCount: row['message_count'] as int? ?? 0,
      lastMessageAgo: _formatLastActivity(lastActivity, enabled),
      lastTopicId: row['last_topic_id'] as String?,
      lastTopicTitle: row['last_topic_title'] as String?,
      isEnabled: enabled,
      isActive: row['is_active'] as bool? ?? false,
      lockedLabel: row['locked_label'] as String?,
    );
  }

  String _formatLastActivity(DateTime? lastActivity, bool enabled) {
    if (!enabled) return '—';
    if (lastActivity == null) return 'sin actividad';
    return formatTimeAgo(lastActivity);
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
      status: _statusFromRow(row['status'] as String?),
    );
  }

  TopicStatus _statusFromRow(String? raw) {
    return switch (raw) {
      'pending' => TopicStatus.pending,
      'rejected' => TopicStatus.rejected,
      _ => TopicStatus.published,
    };
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

  String _generateTopicId(String title) {
    var slug = title.toLowerCase();
    const replacements = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n',
    };
    for (final entry in replacements.entries) {
      slug = slug.replaceAll(entry.key, entry.value);
    }
    slug = slug
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'tema';
    if (slug.length > 40) slug = slug.substring(0, 40);
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '$slug-$suffix';
  }

  ForumReply _replyFromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.parse(row['created_at'] as String);
    final editedRaw = row['edited_at'] as String?;
    final deletedRaw = row['deleted_at'] as String?;
    return ForumReply(
      id: _idFromRow(row['id']),
      topicId: row['topic_id'] as String,
      authorHandle: row['author_handle'] as String,
      timeAgo: formatTimeAgo(createdAt),
      content: normalizeStoredText(row['content'] as String? ?? ''),
      commentCount: 0,
      likeCount: row['like_count'] as int? ?? 0,
      authorId: _optionalIdFromRow(row['author_id']),
      authorAvatarUrl: _avatarUrlFromRow(row),
      parentReplyId: _optionalIdFromRow(row['parent_reply_id']),
      createdAt: createdAt,
      editedAt: editedRaw == null ? null : DateTime.parse(editedRaw).toLocal(),
      deletedAt:
          deletedRaw == null ? null : DateTime.parse(deletedRaw).toLocal(),
    );
  }

  String _idFromRow(dynamic value) {
    return value?.toString() ?? '';
  }

  String? _optionalIdFromRow(dynamic value) {
    if (value == null) return null;
    final id = value.toString();
    return id.isEmpty ? null : id;
  }
}

class ForumsRemoteUnavailableException implements Exception {
  const ForumsRemoteUnavailableException();
}

ForumsRepository createForumsRepository() {
  return ForumsRepository(client: SupabaseBootstrap.client);
}

bool canAccessForumRemote(ForumCategory? forum) {
  return forum != null && forum.isEnabled;
}
