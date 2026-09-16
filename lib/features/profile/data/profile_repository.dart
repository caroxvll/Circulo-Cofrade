import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/forum.dart';
import '../../../shared/models/mention_candidate.dart';
import '../../../shared/models/profile_activity.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/models/user_role.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _avatarBucket = 'avatars';
  static const _maxAvatarBytes = 2 * 1024 * 1024;

  bool get isAvailable => _client != null;

  Future<UserProfile?> fetchByUserId(String userId) async {
    if (_client == null) return null;

    final row = await _client!
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return _fromRow(row);
  }

  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
    String? handle,
    String? address,
    String? foundedLabel,
    String? website,
  }) async {
    if (_client == null) {
      throw const ProfileUnavailableException();
    }

    final payload = <String, dynamic>{
      'display_name': displayName.trim(),
      'bio': bio.trim(),
      'address': address?.trim() ?? '',
      'founded_label': foundedLabel?.trim() ?? '',
      'website': website?.trim() ?? '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (handle != null) {
      payload['handle'] = _normalizeHandle(handle);
    }

    final row = await _client!
        .from('profiles')
        .update(payload)
        .eq('id', userId)
        .select()
        .single();

    return _fromRow(row);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_client == null) {
      throw const ProfileUnavailableException();
    }
    if (bytes.length > _maxAvatarBytes) {
      throw const AvatarTooLargeException();
    }

    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path = '$userId/avatar.$extension';

    await _client!.storage
        .from(_avatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
        );

    final publicUrl = _client!.storage.from(_avatarBucket).getPublicUrl(path);

    final cacheBusted = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    await _client!
        .from('profiles')
        .update({
          'avatar_url': cacheBusted,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);

    return cacheBusted;
  }

  Future<String?> findProfileIdByHandle(String handle) async {
    if (_client == null) return null;

    final normalized = handle.replaceAll('@', '').trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final row = await _client!
        .from('profiles')
        .select('id')
        .isFilter('suspended_at', null)
        .ilike('handle', normalized)
        .maybeSingle();

    return row?['id'] as String?;
  }

  Future<List<MentionCandidate>> searchMentionCandidates(
    String query, {
    int limit = 8,
  }) async {
    if (_client == null) return [];

    final normalized = query.replaceAll('@', '').trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final rows = await _client!
        .from('profiles')
        .select('id, handle, display_name, avatar_url, suspended_at')
        .isFilter('suspended_at', null)
        .ilike('handle', '$normalized%')
        .order('handle')
        .limit(limit);

    return [
      for (final row in rows)
        MentionCandidate(
          id: row['id'] as String,
          handle: row['handle'] as String,
          displayName:
              row['display_name'] as String? ?? row['handle'] as String,
          avatarUrl: row['avatar_url'] as String?,
        ),
    ];
  }

  Future<List<ProfileActivity>> fetchUserActivity(String userId) async {
    if (_client == null) return [];

    try {
      final topicRows = await _client!
          .from('forum_topics')
          .select(
            'id, forum_id, title, excerpt, created_at, status, '
            'view_count, comment_count',
          )
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      final replyRows = await _client!
          .from('forum_replies')
          .select(
            'id, topic_id, content, created_at, like_count, '
            'forum_topics(forum_id, title, view_count, comment_count)',
          )
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(30);

      final forumMeta = await _fetchForumMeta([
        for (final row in topicRows) row['forum_id'] as String,
        for (final row in replyRows)
          (row['forum_topics'] as Map<String, dynamic>?)?['forum_id']
              as String?,
      ]);

      final items = <({DateTime at, ProfileActivity activity})>[];

      for (final row in topicRows) {
        final createdAt = DateTime.parse(row['created_at'] as String);
        final forumId = row['forum_id'] as String;
        final meta = forumMeta[forumId];
        items.add((
          at: createdAt,
          activity: ProfileActivity(
            id: row['id'] as String,
            type: ProfileActivityType.topic,
            forumId: forumId,
            forumName: meta?.name ?? forumId,
            forumIconKey: meta?.iconKey,
            topicId: row['id'] as String,
            title: row['title'] as String,
            preview: row['excerpt'] as String? ?? '',
            timeAgo: formatTimeAgo(createdAt),
            topicStatus: _topicStatusFromRow(row['status'] as String?),
            viewCount: row['view_count'] as int? ?? 0,
            commentCount: row['comment_count'] as int? ?? 0,
          ),
        ));
      }

      for (final row in replyRows) {
        final topic = row['forum_topics'] as Map<String, dynamic>?;
        if (topic == null) continue;
        final createdAt = DateTime.parse(row['created_at'] as String);
        final content = row['content'] as String? ?? '';
        final forumId = topic['forum_id'] as String;
        final meta = forumMeta[forumId];
        items.add((
          at: createdAt,
          activity: ProfileActivity(
            id: row['id'].toString(),
            type: ProfileActivityType.reply,
            forumId: forumId,
            forumName: meta?.name ?? forumId,
            forumIconKey: meta?.iconKey,
            topicId: row['topic_id'] as String,
            title: topic['title'] as String? ?? 'Hilo',
            preview: content.length > 100
                ? '${content.substring(0, 97)}...'
                : content,
            timeAgo: formatTimeAgo(createdAt),
            viewCount: topic['view_count'] as int? ?? 0,
            commentCount: topic['comment_count'] as int? ?? 0,
            reactionCount: row['like_count'] as int? ?? 0,
          ),
        ));
      }

      items.sort((a, b) {
        final aPending =
            a.activity.isTopic && a.activity.topicStatus == TopicStatus.pending;
        final bPending =
            b.activity.isTopic && b.activity.topicStatus == TopicStatus.pending;
        if (aPending != bPending) return aPending ? -1 : 1;
        return b.at.compareTo(a.at);
      });
      return items.take(30).map((e) => e.activity).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, _ForumMeta>> _fetchForumMeta(Iterable<String?> forumIds) async {
    if (_client == null) return {};

    final ids = forumIds.whereType<String>().toSet();
    if (ids.isEmpty) return {};

    final rows = await _client!
        .from('forum_pillars')
        .select('id, name, icon_key')
        .inFilter('id', ids.toList());

    return {
      for (final row in rows)
        row['id'] as String: _ForumMeta(
          name: row['name'] as String? ?? row['id'] as String,
          iconKey: row['icon_key'] as String?,
        ),
    };
  }

  TopicStatus _topicStatusFromRow(String? raw) {
    return switch (raw) {
      'pending' => TopicStatus.pending,
      'rejected' => TopicStatus.rejected,
      _ => TopicStatus.published,
    };
  }

  UserProfile _fromRow(Map<String, dynamic> row) {
    final handle = row['handle'] as String;
    return UserProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      handle: handle.startsWith('@') ? handle : '@$handle',
      bio: row['bio'] as String? ?? '',
      publicationCount: row['publication_count'] as int? ?? 0,
      followerCount: row['follower_count'] as int? ?? 0,
      avatarIcon: Icons.face_3,
      avatarUrl: row['avatar_url'] as String?,
      isVerified: row['verified'] as bool? ?? false,
      address: row['address'] as String? ?? '',
      foundedLabel: row['founded_label'] as String? ?? '',
      website: row['website'] as String? ?? '',
      role: UserRole.fromString(row['role'] as String?),
      isSuspended: row['suspended_at'] != null,
      suspendedReason: row['suspended_reason'] as String?,
      trophyPoints: row['trophy_points'] as int? ?? 0,
    );
  }

  String _normalizeHandle(String handle) {
    var value = handle.trim().toLowerCase();
    if (value.startsWith('@')) value = value.substring(1);
    return value.replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }
}

class _ForumMeta {
  const _ForumMeta({required this.name, this.iconKey});

  final String name;
  final String? iconKey;
}

class ProfileUnavailableException implements Exception {
  const ProfileUnavailableException();
}

class AvatarTooLargeException implements Exception {
  const AvatarTooLargeException();
}

ProfileRepository createProfileRepository() {
  return ProfileRepository(client: SupabaseBootstrap.client);
}

String handleFromUser(User user) {
  final meta = user.userMetadata ?? {};
  final raw =
      meta['handle'] as String? ?? user.email?.split('@').first ?? 'cofrade';
  final normalized = raw.replaceAll('@', '');
  return normalized.startsWith('@') ? normalized : '@$normalized';
}
