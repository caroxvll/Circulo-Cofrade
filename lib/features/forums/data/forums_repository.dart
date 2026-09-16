import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/forum.dart';
import '../utils/topic_list_order.dart';
import 'forum_about_moderator.dart';
import 'forum_icons.dart';
import 'mock_forums.dart';
import 'reply_moderation_exception.dart';

class ForumsRepository {
  ForumsRepository({SupabaseClient? client}) : _client = client;

  static const _topicCoversBucket = 'topic-covers';
  static const _officialPostImagesBucket = 'forum-post-images';
  static const maxTopicCoverBytes = 3 * 1024 * 1024;
  static const maxOfficialPostImageBytes = 5 * 1024 * 1024;

  /// Foros donde la Junta puede crear temas destacados de sistema.
  static const pinnedTopicParentForumIds = [
    'foro-cofradiero',
    'pentagrama-cofrade',
    'martillo-trabajadera',
  ];

  final SupabaseClient? _client;

  /// PostgREST exige el FK explícito tras añadir `parent_reply_id` en respuestas.
  static const _profileAuthorSelect =
      'profiles!author_id(avatar_url, verified, suspended_at, trophy_points)';

  bool get _useRemote => _client != null;

  Future<List<ForumCategory>> fetchPillars() async {
    if (!_useRemote) return visibleForumCategories;

    final rows = await _client!
        .from('forum_pillars')
        .select()
        .order('sort_order', ascending: true);

    return visibleForumPillars(rows.map(_pillarFromRow).toList());
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

  static const forumsListHeroConfigKey = 'forums_list_hero_image_url';

  Future<String?> fetchForumsListHeroImageUrl() async {
    if (!_useRemote) return null;

    final row = await _client!
        .from('app_config')
        .select('value')
        .eq('key', forumsListHeroConfigKey)
        .maybeSingle();

    final value = row?['value'] as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<List<ForumTopic>> fetchTopics(String forumId) async {
    if (!_useRemote) return topicsForForum(forumId);

    final rows = await _client!
        .from('forum_topics')
        .select('*, $_profileAuthorSelect')
        .eq('forum_id', forumId)
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return orderForumTopics(
      rows
          .where((row) => !_isAuthorSuspended(row))
          .map(_topicFromRow)
          .toList(),
    );
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

    await _client!.rpc(
      'increment_topic_view',
      params: {'p_topic_id': topicId, 'p_viewer_id': viewerId},
    );
  }

  Future<ForumTopic> createTopic({
    required String forumId,
    required String authorId,
    required String authorHandle,
    required String title,
    required String body,
    String? seasonKey,
    String? relatedForumId,
  }) async {
    if (!_useRemote) {
      throw const ForumsRemoteUnavailableException();
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    final excerpt = plainTextForExcerpt(trimmedBody);
    final related = relatedForumId?.trim();

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
          if (seasonKey != null && seasonKey.isNotEmpty) 'season_key': seasonKey,
          if (related != null && related.isNotEmpty) 'related_forum_id': related,
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
    bool isOfficial = false,
    String? officialCategory,
    String? parentReplyId,
    String? imageUrl,
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
          if (isOfficial) 'is_official': true,
          'official_category': ?officialCategory,
          'parent_reply_id': ?parentReplyId,
          'image_url': ?imageUrl,
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
      await _client!.rpc(
        'update_own_forum_reply',
        params: {'p_reply_id': replyId, 'p_content': content.trim()},
      );
    } on PostgrestException catch (e) {
      throw ReplyModerationException.fromPostgrestMessage(e.message) ??
          const ReplyModerationException(ReplyModerationException.forbidden);
    }
  }

  Future<void> updateOfficialHermandadPost({
    required String replyId,
    required String content,
    required String officialCategory,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    try {
      await _client!.rpc(
        'update_official_hermandad_post',
        params: {
          'p_reply_id': replyId,
          'p_content': content.trim(),
          'p_official_category': officialCategory,
          'p_image_url': imageUrl,
          'p_clear_image': clearImage,
        },
      );
    } on PostgrestException catch (e) {
      throw ReplyModerationException.fromPostgrestMessage(e.message) ??
          const ReplyModerationException(ReplyModerationException.forbidden);
    }
  }

  Future<void> softDeleteReply(String replyId) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    try {
      await _client!.rpc(
        'soft_delete_forum_reply',
        params: {'p_reply_id': replyId},
      );
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
    final iconKey = row['icon_key'] as String?;

    return ForumCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      icon: forumIconFromKey(iconKey),
      headerIcon: forumIconFromKey(iconKey),
      iconKey: iconKey,
      iconImageUrl: row['icon_image_url'] as String?,
      coverImageUrl: row['cover_image_url'] as String?,
      aboutTagline: row['about_tagline'] as String?,
      aboutBody: row['about_body'] as String?,
      forumRules: row['forum_rules'] as String?,
      createdAt: _parseOptionalDate(row['created_at']),
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

  DateTime? _parseOptionalDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.parse(raw).toLocal();
  }

  Future<List<ForumAboutModerator>> fetchForumModerators(String forumId) async {
    if (!_useRemote) return [];

    final rows = await _client!
        .from('forum_moderators')
        .select(
          'profile_id, assigned_at, '
          'profiles!profile_id(handle, avatar_url, role)',
        )
        .eq('forum_id', forumId)
        .order('assigned_at', ascending: true);

    return rows
        .map((row) {
          final profile = row['profiles'];
          if (profile is! Map<String, dynamic>) return null;
          final handle = profile['handle'] as String? ?? '';
          if (handle.isEmpty) return null;
          return ForumAboutModerator(
            handle: handle,
            avatarUrl: profile['avatar_url'] as String?,
            isAdmin: profile['role'] == 'admin',
          );
        })
        .whereType<ForumAboutModerator>()
        .toList();
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
      authorVerified: _authorVerifiedFromRow(row),
      authorTrophyPoints: _trophyPointsFromRow(row),
      status: _statusFromRow(row['status'] as String?),
      isPinned: row['is_pinned'] as bool? ?? false,
      pinSortOrder: row['pin_sort_order'] as int? ?? 0,
      isSystem: row['is_system'] as bool? ?? false,
      seasonKey: row['season_key'] as String?,
      iconKey: row['icon_key'] as String?,
      coverImageUrl: row['cover_image_url'] as String?,
      showHubTitle: row['show_hub_title'] as bool? ?? true,
      isListed: row['is_listed'] as bool? ?? true,
      createdAt: createdAt,
      closeStatus: TopicCloseStatusX.fromDb(row['close_status'] as String?),
      isClosed: row['is_closed'] as bool? ?? false,
      editedAt: row['edited_at'] == null
          ? null
          : DateTime.parse(row['edited_at'] as String),
      relatedForumId: row['related_forum_id'] as String?,
    );
  }

  Future<void> updateTopicAsOwner({
    required String topicId,
    required String title,
    required String body,
    required String excerpt,
    String? coverImageUrl,
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    final patch = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'excerpt': excerpt.trim(),
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (coverImageUrl != null) {
      patch['cover_image_url'] =
          coverImageUrl.trim().isEmpty ? null : coverImageUrl.trim();
    }

    await _client!.from('forum_topics').update(patch).eq('id', topicId);
  }

  Future<void> setTopicCoverAsOwner({
    required String topicId,
    required String? coverImageUrl,
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    final trimmed = coverImageUrl?.trim();
    await _client!.from('forum_topics').update({
      'cover_image_url': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', topicId);
  }

  Future<void> requestTopicClose(String topicId) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    await _client!
        .from('forum_topics')
        .update({'close_status': 'close_requested'})
        .eq('id', topicId);
  }

  Future<void> setReplyFeatured({
    required String replyId,
    required bool featured,
    bool officialHermandadPin = false,
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    if (officialHermandadPin) {
      try {
        await _client!.rpc(
          'set_official_hermandad_post_pinned',
          params: {'p_reply_id': replyId, 'p_pinned': featured},
        );
      } on PostgrestException catch (e) {
        throw ReplyModerationException.fromPostgrestMessage(e.message) ??
            const ReplyModerationException(ReplyModerationException.forbidden);
      }
      return;
    }

    await _client!
        .from('forum_replies')
        .update({'is_featured': featured})
        .eq('id', replyId);
  }

  Future<List<ForumTopic>> fetchPinnedSystemTopics() async {
    final client = _client;
    if (client == null) return [];

    final rows = await client
        .from('forum_topics')
        .select()
        .eq('is_system', true)
        .eq('is_pinned', true)
        .order('pin_sort_order', ascending: true);

    return rows.map(_topicFromRow).toList();
  }

  Future<String> uploadTopicCover({
    required String topicId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final client = _client;
    if (client == null) throw const ForumsRemoteUnavailableException();

    CompressedImage compressed;
    try {
      compressed = await compressImageForUploadAsync(
        bytes,
        maxBytes: maxTopicCoverBytes,
      );
    } on ImageTooLargeAfterCompressException {
      throw const TopicCoverTooLargeException();
    }

    final path = '$topicId/cover.jpg';

    await client.storage
        .from(_topicCoversBucket)
        .uploadBinary(
          path,
          compressed.bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = client.storage
        .from(_topicCoversBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadOfficialPostImage({
    required String topicId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final client = _client;
    if (client == null) throw const ForumsRemoteUnavailableException();

    CompressedImage compressed;
    try {
      compressed = await compressImageForUploadAsync(
        bytes,
        maxBytes: maxOfficialPostImageBytes,
      );
    } on ImageTooLargeAfterCompressException {
      throw const OfficialPostImageTooLargeException();
    }

    final path =
        '$topicId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await client.storage
        .from(_officialPostImagesBucket)
        .uploadBinary(
          path,
          compressed.bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final publicUrl = client.storage
        .from(_officialPostImagesBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> updatePinnedTopicSettings({
    required String topicId,
    String? iconKey,
    String? coverImageUrl,
    int? pinSortOrder,
    bool? isListed,
    String? excerpt,
    String? body,
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    final patch = <String, dynamic>{};
    if (iconKey != null) patch['icon_key'] = iconKey;
    if (coverImageUrl != null) {
      patch['cover_image_url'] = coverImageUrl.trim().isEmpty
          ? null
          : coverImageUrl.trim();
    }
    if (pinSortOrder != null) patch['pin_sort_order'] = pinSortOrder;
    if (isListed != null) patch['is_listed'] = isListed;
    if (excerpt != null) patch['excerpt'] = excerpt.trim();
    if (body != null) patch['body'] = body.trim();
    if (patch.isEmpty) return;

    await _client!.from('forum_topics').update(patch).eq('id', topicId);
  }

  Future<ForumTopic> createPinnedSystemTopic({
    required String forumId,
    required String title,
    String? excerpt,
    String? body,
    String? seasonKey,
    String iconKey = 'church',
  }) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'El título no puede estar vacío');
    }

    final existing = await fetchPinnedSystemTopics();
    final inForum = existing.where((t) => t.forumId == forumId);
    final nextOrder = inForum.isEmpty
        ? 1
        : inForum.map((t) => t.pinSortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final description =
        excerpt?.trim().isNotEmpty == true
            ? excerpt!.trim()
            : 'Espacio de conversación sobre $trimmedTitle.';
    final content =
        body?.trim().isNotEmpty == true
            ? body!.trim()
            : 'Espacio destacado para $trimmedTitle.\n\nComparte noticias y conversación con la comunidad.';

    final topicId = _pinnedTopicId(forumId, trimmedTitle);

    final row = await _client!
        .from('forum_topics')
        .insert({
          'id': topicId,
          'forum_id': forumId,
          'author_handle': '@cofradeo',
          'title': trimmedTitle,
          'excerpt': description,
          'body': content,
          'status': 'published',
          'is_pinned': true,
          'is_system': true,
          'pin_sort_order': nextOrder,
          'is_listed': true,
          'icon_key': iconKey,
          if (seasonKey != null && seasonKey.isNotEmpty) 'season_key': seasonKey,
        })
        .select()
        .single();

    return _topicFromRow(row);
  }

  Future<void> deletePinnedSystemTopic(String topicId) async {
    if (!_useRemote) throw const ForumsRemoteUnavailableException();
    await _client!
        .from('forum_topics')
        .delete()
        .eq('id', topicId)
        .eq('is_system', true);
  }

  String _pinnedTopicId(String forumId, String title) {
    final prefix = switch (forumId) {
      'foro-cofradiero' => 'circulo',
      'martillo-trabajadera' => 'martillo',
      'pentagrama-cofrade' => 'pentagrama',
      _ => forumId.split('-').first,
    };
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'ñ'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '$prefix-${slug.isEmpty ? 'tema' : slug}';
  }

  @Deprecated('Use updatePinnedTopicSettings')
  Future<void> updatePinnedTopicAppearance({
    required String topicId,
    String? iconKey,
    String? coverImageUrl,
  }) =>
      updatePinnedTopicSettings(
        topicId: topicId,
        iconKey: iconKey,
        coverImageUrl: coverImageUrl,
      );

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

  bool _authorVerifiedFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    if (profile is Map<String, dynamic>) {
      return profile['verified'] as bool? ?? false;
    }
    return false;
  }

  int _trophyPointsFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    if (profile is Map<String, dynamic>) {
      return profile['trophy_points'] as int? ?? 0;
    }
    return 0;
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
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
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
      authorVerified: _authorVerifiedFromRow(row),
      authorTrophyPoints: _trophyPointsFromRow(row),
      isOfficial: row['is_official'] as bool? ?? false,
      officialCategory: row['official_category'] as String?,
      parentReplyId: _optionalIdFromRow(row['parent_reply_id']),
      createdAt: createdAt,
      editedAt: editedRaw == null ? null : DateTime.parse(editedRaw).toLocal(),
      deletedAt: deletedRaw == null
          ? null
          : DateTime.parse(deletedRaw).toLocal(),
      isFeatured: row['is_featured'] as bool? ?? false,
      imageUrl: row['image_url'] as String?,
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

class TopicCoverTooLargeException implements Exception {
  const TopicCoverTooLargeException();
}

class OfficialPostImageTooLargeException implements Exception {
  const OfficialPostImageTooLargeException();
}

ForumsRepository createForumsRepository() {
  return ForumsRepository(client: SupabaseBootstrap.client);
}

bool canAccessForumRemote(ForumCategory? forum) {
  return forum != null && forum.isEnabled;
}
