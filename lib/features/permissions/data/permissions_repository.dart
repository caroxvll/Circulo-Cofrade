import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

class ForumModeratorAssignment {
  const ForumModeratorAssignment({
    required this.profileId,
    required this.forumId,
    required this.handle,
    required this.forumName,
    required this.assignedAt,
  });

  final String profileId;
  final String forumId;
  final String handle;
  final String forumName;
  final DateTime assignedAt;
}

class ProfileHandleSearchHit {
  const ProfileHandleSearchHit({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String id;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  String get handleLabel =>
      handle.startsWith('@') ? handle : '@$handle';
}

class HermandadTopicAssignment {
  const HermandadTopicAssignment({
    required this.profileId,
    required this.topicId,
    required this.handle,
    required this.topicTitle,
    required this.assignedAt,
  });

  final String profileId;
  final String topicId;
  final String handle;
  final String topicTitle;
  final DateTime assignedAt;
}

class CreatedHermandadAccount {
  const CreatedHermandadAccount({
    required this.profileId,
    required this.handle,
    required this.displayName,
    required this.email,
    required this.temporaryPassword,
    this.topicId,
  });

  final String profileId;
  final String handle;
  final String displayName;
  final String email;
  final String temporaryPassword;
  final String? topicId;

  String get handleLabel => handle.startsWith('@') ? handle : '@$handle';
}

class PermissionsRepository {
  PermissionsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<Set<String>> fetchModeratedForumIds(String userId) async {
    if (_client == null) return {};

    final rows = await _client!
        .from('forum_moderators')
        .select('forum_id')
        .eq('profile_id', userId);

    return {for (final row in rows) row['forum_id'] as String};
  }

  Future<Set<String>> fetchAllForumIds() async {
    if (_client == null) return {};

    final rows = await _client!.from('forum_pillars').select('id');
    return {for (final row in rows) row['id'] as String};
  }

  Future<Set<String>> fetchHermandadTopicIds(String userId) async {
    if (_client == null) return {};

    final rows = await _client!
        .from('hermandad_topic_accounts')
        .select('topic_id')
        .eq('profile_id', userId);

    return {for (final row in rows) row['topic_id'] as String};
  }

  Future<bool> isBannedFromForum({
    required String userId,
    required String forumId,
  }) async {
    if (_client == null) return false;

    final row = await _client!
        .from('forum_bans')
        .select('banned_until')
        .eq('profile_id', userId)
        .eq('forum_id', forumId)
        .maybeSingle();

    if (row == null) return false;
    final until = row['banned_until'];
    if (until == null) return true;
    return DateTime.parse(until as String).isAfter(DateTime.now().toUtc());
  }

  Future<List<ForumModeratorAssignment>> fetchAllModeratorAssignments() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_moderators')
        .select(
          'profile_id, forum_id, assigned_at, '
          'profiles!profile_id(handle), forum_pillars(name)',
        )
        .order('assigned_at', ascending: false);

    return rows.map(_assignmentFromRow).toList();
  }

  Future<void> assignForumModerator({
    required String profileId,
    required String forumId,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    await _client!.from('forum_moderators').upsert({
      'profile_id': profileId,
      'forum_id': forumId,
      'assigned_by': _client!.auth.currentUser?.id,
    });
  }

  Future<void> removeForumModerator({
    required String profileId,
    required String forumId,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    await _client!
        .from('forum_moderators')
        .delete()
        .eq('profile_id', profileId)
        .eq('forum_id', forumId);
  }

  Future<void> banFromForum({
    required String profileId,
    required String forumId,
    required String reason,
    DateTime? until,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    await _client!.from('forum_bans').upsert({
      'profile_id': profileId,
      'forum_id': forumId,
      'reason': reason.trim(),
      'banned_by': _client!.auth.currentUser?.id,
      if (until != null) 'banned_until': until.toUtc().toIso8601String(),
    });
  }

  Future<void> unbanFromForum({
    required String profileId,
    required String forumId,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    await _client!
        .from('forum_bans')
        .delete()
        .eq('profile_id', profileId)
        .eq('forum_id', forumId);
  }

  Future<String?> fetchProfileIdByHandle(String handle) async {
    if (_client == null) return null;

    final normalized = handle.trim().replaceFirst('@', '').toLowerCase();
    if (normalized.isEmpty) return null;

    final row = await _client!
        .from('profiles')
        .select('id')
        .eq('handle', normalized)
        .maybeSingle();

    return row?['id'] as String?;
  }

  Future<List<ProfileHandleSearchHit>> searchProfilesByHandlePrefix(
    String rawQuery, {
    int limit = 8,
  }) async {
    if (_client == null) return [];

    final normalized = rawQuery.trim().replaceFirst('@', '').toLowerCase();
    if (normalized.length < 2) return [];

    final rows = await _client!
        .from('profiles')
        .select('id, handle, display_name, avatar_url, verified')
        .isFilter('suspended_at', null)
        .ilike('handle', '$normalized%')
        .order('handle')
        .limit(limit);

    return [
      for (final row in rows)
        ProfileHandleSearchHit(
          id: row['id'] as String,
          handle: row['handle'] as String,
          displayName: row['display_name'] as String? ?? row['handle'] as String,
          avatarUrl: row['avatar_url'] as String?,
          isVerified: row['verified'] as bool? ?? false,
        ),
    ];
  }

  Future<List<HermandadTopicAssignment>> fetchHermandadAssignments() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('hermandad_topic_accounts')
        .select(
          'profile_id, topic_id, created_at, '
          'profiles(handle), forum_topics(title)',
        )
        .order('created_at', ascending: false);

    return rows.map(_hermandadAssignmentFromRow).toList();
  }

  Future<List<({String id, String title})>> fetchHermandadBoardTopics() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_topics')
        .select('id, title')
        .eq('forum_id', 'hermandades')
        .order('title', ascending: true);

    return [
      for (final row in rows)
        (id: row['id'] as String, title: row['title'] as String),
    ];
  }

  Future<void> assignHermandadTopic({
    required String profileId,
    required String topicId,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    await _client!.from('hermandad_topic_accounts').upsert({
      'profile_id': profileId,
      'topic_id': topicId,
    });
  }

  Future<void> removeHermandadAssignment({
    required String profileId,
    required String topicId,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    await _client!
        .from('hermandad_topic_accounts')
        .delete()
        .eq('profile_id', profileId)
        .eq('topic_id', topicId);
  }

  /// Crea cuenta Auth + perfil brotherhood verificado (Edge Function).
  /// Opcionalmente vincula al tablón. Devuelve la contraseña temporal.
  Future<CreatedHermandadAccount> createHermandadAccount({
    required String email,
    required String handle,
    required String displayName,
    String? password,
    String? topicId,
  }) async {
    if (_client == null) throw const PermissionsUnavailableException();

    final response = await _client!.functions.invoke(
      'create-hermandad-account',
      body: {
        'email': email.trim(),
        'handle': handle.trim(),
        'displayName': displayName.trim(),
        if (password != null && password.trim().isNotEmpty)
          'password': password.trim(),
        if (topicId != null && topicId.isNotEmpty) 'topicId': topicId,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw const HermandadAccountProvisionException(
        'Respuesta inválida al crear la cuenta',
      );
    }
    final map = Map<String, dynamic>.from(data);
    final error = map['error'] as String?;
    if (error != null && error.isNotEmpty) {
      throw HermandadAccountProvisionException(error);
    }

    final profileId = map['profileId'] as String?;
    final createdHandle = map['handle'] as String?;
    final temporaryPassword = map['temporaryPassword'] as String?;
    if (profileId == null ||
        createdHandle == null ||
        temporaryPassword == null) {
      throw const HermandadAccountProvisionException(
        'La cuenta no devolvió todos los datos necesarios',
      );
    }

    return CreatedHermandadAccount(
      profileId: profileId,
      handle: createdHandle,
      displayName: map['displayName'] as String? ?? displayName,
      email: map['email'] as String? ?? email,
      topicId: map['topicId'] as String?,
      temporaryPassword: temporaryPassword,
    );
  }

  ForumModeratorAssignment _assignmentFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final pillar = row['forum_pillars'] as Map<String, dynamic>?;
    return ForumModeratorAssignment(
      profileId: row['profile_id'] as String,
      forumId: row['forum_id'] as String,
      handle: profile?['handle'] as String? ?? '',
      forumName: pillar?['name'] as String? ?? row['forum_id'] as String,
      assignedAt: DateTime.parse(row['assigned_at'] as String),
    );
  }

  HermandadTopicAssignment _hermandadAssignmentFromRow(
    Map<String, dynamic> row,
  ) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final topic = row['forum_topics'] as Map<String, dynamic>?;
    return HermandadTopicAssignment(
      profileId: row['profile_id'] as String,
      topicId: row['topic_id'] as String,
      handle: profile?['handle'] as String? ?? '',
      topicTitle: topic?['title'] as String? ?? row['topic_id'] as String,
      assignedAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class PermissionsUnavailableException implements Exception {
  const PermissionsUnavailableException();
}

class HermandadAccountProvisionException implements Exception {
  const HermandadAccountProvisionException(this.message);

  final String message;

  @override
  String toString() => message;
}

PermissionsRepository createPermissionsRepository() {
  return PermissionsRepository(client: SupabaseBootstrap.client);
}
