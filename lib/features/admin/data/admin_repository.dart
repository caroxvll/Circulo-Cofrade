import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/calendar_event.dart';
import '../../../shared/models/forum.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../../forums/data/forum_icons.dart';

class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.status,
    required this.timeAgo,
    required this.reporterId,
    this.reporterHandle,
    this.targetHandle,
    this.targetForumId,
    this.targetTopicId,
    this.authorProfileId,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String details;
  final String status;
  final String timeAgo;
  final String reporterId;
  final String? reporterHandle;
  final String? targetHandle;
  final String? targetForumId;
  final String? targetTopicId;
  final String? authorProfileId;
}

/// Varios reportes sobre el mismo objetivo, agrupados para la Junta.
class ModerationReportGroup {
  const ModerationReportGroup({
    required this.targetType,
    required this.targetId,
    required this.reports,
    this.targetHandle,
    this.targetForumId,
    this.targetTopicId,
    this.authorProfileId,
  });

  final String targetType;
  final String targetId;
  final List<ModerationReport> reports;
  final String? targetHandle;
  final String? targetForumId;
  final String? targetTopicId;
  final String? authorProfileId;

  int get count => reports.length;

  String get latestTimeAgo => reports.first.timeAgo;

  String get reasonsSummary {
    final unique = <String>{};
    for (final report in reports) {
      unique.add(report.reason);
    }
    return unique.join(', ');
  }

  String get targetLabel {
    switch (targetType) {
      case 'profile':
        final handle = targetHandle;
        if (handle == null || handle.isEmpty) return 'Perfil reportado';
        return handle.startsWith('@') ? handle : '@$handle';
      case 'topic':
        return targetHandle ?? 'Tema reportado';
      case 'reply':
        return targetHandle ?? 'Respuesta reportada';
      default:
        return '$targetType · $targetId';
    }
  }
}

List<ModerationReportGroup> groupModerationReports(
  List<ModerationReport> reports,
) {
  final byTarget = <String, List<ModerationReport>>{};
  for (final report in reports) {
    final key = '${report.targetType}:${report.targetId}';
    byTarget.putIfAbsent(key, () => []).add(report);
  }

  final groups = <ModerationReportGroup>[];
  for (final entry in byTarget.entries) {
    final list = entry.value;
    groups.add(
      ModerationReportGroup(
        targetType: list.first.targetType,
        targetId: list.first.targetId,
        targetHandle: list.first.targetHandle,
        targetForumId: list.first.targetForumId,
        targetTopicId: list.first.targetTopicId,
        authorProfileId: list.first.authorProfileId,
        reports: list,
      ),
    );
  }

  groups.sort((a, b) {
    final ai = reports.indexWhere((r) => r.id == a.reports.first.id);
    final bi = reports.indexWhere((r) => r.id == b.reports.first.id);
    return ai.compareTo(bi);
  });
  return groups;
}

class AdminRepository {
  AdminRepository({SupabaseClient? client}) : _client = client;

  static const _forumIconsBucket = 'forum-icons';
  static const _forumCoversBucket = 'forum-covers';
  static const forumsListHeroConfigKey = 'forums_list_hero_image_url';
  static const _maxPillarIconBytes = 3 * 1024 * 1024;
  static const _maxPillarCoverBytes = 5 * 1024 * 1024;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<SignupPulse> fetchSignupPulse() async {
    if (_client == null) throw const AdminUnavailableException();
    final row = await _client!.rpc('admin_signup_pulse');
    if (row is! Map) throw const AdminUnavailableException();
    return SignupPulse.fromJson(Map<String, dynamic>.from(row));
  }

  Future<XIngestSettings> fetchXIngestSettings() async {
    if (_client == null) throw const AdminUnavailableException();
    final row = await _client!
        .from('x_ingest_settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    if (row == null) throw const AdminUnavailableException();
    return XIngestSettings.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> saveXIngestSettings({
    required bool enabled,
    required int intervalMinutes,
    required int maxPostsPerAccount,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.from('x_ingest_settings').update({
      'enabled': enabled,
      'interval_minutes': intervalMinutes,
      'max_posts_per_account': maxPostsPerAccount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': _client!.auth.currentUser?.id,
    }).eq('id', 1);
  }

  Future<List<XIngestAccount>> fetchXIngestAccounts() async {
    if (_client == null) return [];
    final rows = await _client!
        .from('x_ingest_accounts')
        .select('*, forum_topics(title)')
        .order('handle');
    return [
      for (final row in rows)
        XIngestAccount.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> upsertXIngestAccount({
    required String topicId,
    required String handle,
    String? id,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    final payload = {
      'topic_id': topicId,
      'handle': handle.trim().replaceFirst(RegExp(r'^@+'), ''),
    };
    if (id != null && id.isNotEmpty) {
      await _client!.from('x_ingest_accounts').update(payload).eq('id', id);
      return;
    }
    await _client!.from('x_ingest_accounts').upsert(
          payload,
          onConflict: 'topic_id',
        );
  }

  Future<void> setXIngestAccountEnabled({
    required String id,
    required bool enabled,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!
        .from('x_ingest_accounts')
        .update({'ingest_enabled': enabled})
        .eq('id', id);
  }

  Future<void> deleteXIngestAccount(String id) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.from('x_ingest_accounts').delete().eq('id', id);
  }

  Future<List<XIngestDraft>> fetchXIngestDrafts({String status = 'pending'}) async {
    if (_client == null) return [];
    final rows = await _client!
        .from('x_ingest_drafts')
        .select('*, forum_topics(title)')
        .eq('status', status)
        .order('created_at', ascending: false)
        .limit(80);
    return [
      for (final row in rows)
        XIngestDraft.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, dynamic>> runXIngestPull({
    bool force = true,
    bool skipBacklog = false,
    String? accountId,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    final response = await _client!.functions.invoke(
      'x-ingest-pull',
      body: {
        'force': force,
        'skipBacklog': skipBacklog,
        if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      },
    );
    final data = response.data;
    if (data is! Map) throw const AdminUnavailableException();
    final map = Map<String, dynamic>.from(data);
    final error = map['error']?.toString();
    if (error != null && error.isNotEmpty) {
      throw XIngestException(error);
    }
    return map;
  }

  Future<void> publishXIngestDraft({
    required String draftId,
    required String topicId,
    required String category,
    required String body,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.rpc(
      'x_ingest_publish_draft',
      params: {
        'p_draft_id': draftId,
        'p_topic_id': topicId,
        'p_category': category,
        'p_body': body,
      },
    );
  }

  Future<void> discardXIngestDraft(String draftId) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.rpc(
      'x_ingest_discard_draft',
      params: {'p_draft_id': draftId},
    );
  }

  Future<List<ForumTopic>> fetchPendingTopics() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_topics')
        .select(
          '*, profiles!author_id(avatar_url, display_name, handle, verified)',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map(_topicFromRow).toList();
  }

  /// Publicaciones oficiales recientes (Junta).
  Future<List<ForumTopic>> fetchEditorialPosts({int limit = 40}) async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_topics')
        .select(
          '*, profiles!author_id(avatar_url, display_name, handle, verified)',
        )
        .eq('is_editorial', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map(_topicFromRow).toList();
  }

  /// Crea una publicación oficial. Admin → publicada; moderador → pendiente.
  Future<ForumTopic> createEditorialPost({
    required String title,
    required String body,
    String? excerpt,
    String? coverImageUrl,
    String? calendarEventId,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    final row = await _client!.rpc(
      'create_editorial_post',
      params: {
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_excerpt': excerpt?.trim(),
        'p_cover_image_url': coverImageUrl?.trim(),
        if (calendarEventId != null && calendarEventId.trim().isNotEmpty)
          'p_calendar_event_id': calendarEventId.trim(),
      },
    );

    if (row is! Map<String, dynamic>) {
      throw const AdminUnavailableException();
    }
    return _topicFromRow(row);
  }

  Future<void> setEditorialCover({
    required String topicId,
    required String coverImageUrl,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.rpc(
      'set_editorial_cover',
      params: {
        'p_topic_id': topicId,
        'p_cover_image_url': coverImageUrl,
      },
    );
  }

  /// Portada + fotos de detrás. [galleryImageUrls] no incluye la portada.
  Future<void> setEditorialGallery({
    required String topicId,
    required String coverImageUrl,
    required List<String> galleryImageUrls,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client.rpc(
      'set_editorial_gallery',
      params: {
        'p_topic_id': topicId,
        'p_cover_image_url': coverImageUrl,
        'p_gallery_image_urls': galleryImageUrls,
      },
    );
  }

  /// Presign Stream (POST) o R2 (PUT). Requiere Edge Function desplegada.
  Future<
      ({
        String mode,
        String uploadMethod,
        String uploadUrl,
        String publicUrl,
        String objectKey,
        String? posterUrl,
        String? externalId,
        int? maxBytes,
      })> requestEditorialVideoUpload({
    required String topicId,
    required String contentType,
    required int byteLength,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    final response = await _client!.functions.invoke(
      'editorial-video-upload',
      body: {
        'topicId': topicId,
        'contentType': contentType,
        'byteLength': byteLength,
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw const AdminUnavailableException();
    }
    final uploadUrl = data['uploadUrl']?.toString();
    final publicUrl = data['publicUrl']?.toString();
    final objectKey = data['objectKey']?.toString();
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        publicUrl == null ||
        publicUrl.isEmpty ||
        objectKey == null ||
        objectKey.isEmpty) {
      throw const AdminUnavailableException();
    }
    return (
      mode: data['mode']?.toString() ?? 'r2',
      uploadMethod: data['uploadMethod']?.toString() ?? 'PUT',
      uploadUrl: uploadUrl,
      publicUrl: publicUrl,
      objectKey: objectKey,
      posterUrl: data['posterUrl']?.toString(),
      externalId: data['externalId']?.toString() ?? objectKey,
      maxBytes: (data['maxBytes'] as num?)?.toInt(),
    );
  }

  Future<void> setEditorialVideo({
    required String topicId,
    String? videoUrl,
    String? videoPosterUrl,
    String videoStatus = 'ready',
    String? videoProvider,
    String? videoExternalId,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.rpc(
      'set_editorial_video',
      params: {
        'p_topic_id': topicId,
        'p_video_url': videoUrl,
        'p_video_poster_url': videoPosterUrl,
        'p_video_status': videoStatus,
        'p_video_provider': videoProvider,
        'p_video_external_id': videoExternalId,
      },
    );
  }

  /// Consulta Stream y marca ready si ya terminó el HLS.
  Future<bool> finalizeEditorialVideo({required String topicId}) async {
    if (_client == null) throw const AdminUnavailableException();
    final response = await _client!.functions.invoke(
      'editorial-video-finalize',
      body: {'topicId': topicId},
    );
    final data = response.data;
    if (data is! Map) return false;
    return data['ready'] == true;
  }

  Future<List<ModerationReport>> fetchPendingReports() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('reports')
        .select('*, profiles!reporter_id(handle)')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(100);

    final reports = rows.map(_reportFromRow).toList();
    return _enrichReportTargets(reports);
  }

  Future<void> resolveReport(String reportId) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('reports')
        .update({'status': 'resolved'})
        .eq('id', reportId);
  }

  Future<void> resolveReportsForTarget({
    required String targetType,
    required String targetId,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('reports')
        .update({'status': 'resolved'})
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .eq('status', 'pending');
  }

  Future<void> suspendProfile({
    required String profileId,
    required String reason,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('profiles')
        .update({
          'suspended_at': DateTime.now().toUtc().toIso8601String(),
          'suspended_reason': reason.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', profileId);
  }

  Future<void> unsuspendProfile(String profileId) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('profiles')
        .update({
          'suspended_at': null,
          'suspended_reason': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', profileId);
  }

  Future<void> setProfileVerified({
    required String profileId,
    required bool verified,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('profiles')
        .update({
          'verified': verified,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', profileId);
  }

  Future<void> setProfileChronicler({
    required String profileId,
    required bool chronicler,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('profiles')
        .update({
          'is_chronicler': chronicler,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', profileId);
  }

  /// Permiso aparte de la verificación: solo publicar noticias.
  Future<void> setNewsPublisher({
    required String profileId,
    required bool enabled,
  }) async {
    final client = _client;
    if (client == null) throw const AdminUnavailableException();

    if (!enabled) {
      await client.from('news_publishers').delete().eq('profile_id', profileId);
      return;
    }

    await client.from('news_publishers').upsert({
      'profile_id': profileId,
      'assigned_by': client.auth.currentUser?.id,
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Propone eventos (quedan en revisión) y también puede publicar noticias.
  Future<void> setCalendarContributor({
    required String profileId,
    required bool enabled,
  }) async {
    final client = _client;
    if (client == null) throw const AdminUnavailableException();

    if (!enabled) {
      await client
          .from('calendar_contributors')
          .delete()
          .eq('profile_id', profileId);
      return;
    }

    final assignedBy = client.auth.currentUser?.id;
    final assignedAt = DateTime.now().toUtc().toIso8601String();
    await client.from('calendar_contributors').upsert({
      'profile_id': profileId,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt,
    });
    await client.from('news_publishers').upsert({
      'profile_id': profileId,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt,
    });
  }

  Future<void> unifyNoticias({
    required String topicId,
    required String otherTopicId,
  }) async {
    final client = _client;
    if (client == null) throw const AdminUnavailableException();
    await client.rpc(
      'unify_noticias',
      params: {
        'p_topic_ids': [topicId, otherTopicId],
      },
    );
  }

  Future<void> splitNoticia(String topicId) async {
    final client = _client;
    if (client == null) throw const AdminUnavailableException();
    await client.rpc('split_noticia', params: {'p_topic_id': topicId});
  }

  Future<List<ModerationReport>> _enrichReportTargets(
    List<ModerationReport> reports,
  ) async {
    if (_client == null || reports.isEmpty) return reports;

    final profileIds = reports
        .where((r) => r.targetType == 'profile')
        .map((r) => r.targetId)
        .toSet();
    final topicIds = reports
        .where((r) => r.targetType == 'topic')
        .map((r) => r.targetId)
        .toSet();
    final replyIds = reports
        .where((r) => r.targetType == 'reply')
        .map((r) => r.targetId)
        .toSet();

    final handles = <String, String>{};
    if (profileIds.isNotEmpty) {
      final rows = await _client!
          .from('profiles')
          .select('id, handle')
          .inFilter('id', profileIds.toList());
      for (final row in rows) {
        handles[row['id'] as String] = row['handle'] as String;
      }
    }

    final topics = <String, Map<String, dynamic>>{};
    if (topicIds.isNotEmpty) {
      final rows = await _client!
          .from('forum_topics')
          .select('id, title, forum_id, author_id')
          .inFilter('id', topicIds.toList());
      for (final row in rows) {
        topics[row['id'] as String] = row;
      }
    }

    final replies = <String, Map<String, dynamic>>{};
    if (replyIds.isNotEmpty) {
      final rows = await _client!
          .from('forum_replies')
          .select(
            'id, content, topic_id, author_id, forum_topics(forum_id, title)',
          )
          .inFilter('id', replyIds.toList());
      for (final row in rows) {
        replies[row['id'].toString()] = row;
      }
    }

    return [
      for (final report in reports)
        _enrichSingleReport(
          report,
          handles: handles,
          topics: topics,
          replies: replies,
        ),
    ];
  }

  ModerationReport _enrichSingleReport(
    ModerationReport report, {
    required Map<String, String> handles,
    required Map<String, Map<String, dynamic>> topics,
    required Map<String, Map<String, dynamic>> replies,
  }) {
    switch (report.targetType) {
      case 'profile':
        return ModerationReport(
          id: report.id,
          targetType: report.targetType,
          targetId: report.targetId,
          reason: report.reason,
          details: report.details,
          status: report.status,
          timeAgo: report.timeAgo,
          reporterId: report.reporterId,
          reporterHandle: report.reporterHandle,
          targetHandle: handles[report.targetId],
          authorProfileId: report.targetId,
        );
      case 'topic':
        final topic = topics[report.targetId];
        return ModerationReport(
          id: report.id,
          targetType: report.targetType,
          targetId: report.targetId,
          reason: report.reason,
          details: report.details,
          status: report.status,
          timeAgo: report.timeAgo,
          reporterId: report.reporterId,
          reporterHandle: report.reporterHandle,
          targetHandle: topic?['title'] as String?,
          targetForumId: topic?['forum_id'] as String?,
          targetTopicId: report.targetId,
          authorProfileId: topic?['author_id'] as String?,
        );
      case 'reply':
        final reply = replies[report.targetId];
        final topicMeta = reply?['forum_topics'];
        final topicTitle = topicMeta is Map<String, dynamic>
            ? topicMeta['title'] as String?
            : null;
        final forumId = topicMeta is Map<String, dynamic>
            ? topicMeta['forum_id'] as String?
            : null;
        final content = reply?['content'] as String? ?? '';
        final preview = content.length > 48
            ? '${content.substring(0, 45)}…'
            : content;
        return ModerationReport(
          id: report.id,
          targetType: report.targetType,
          targetId: report.targetId,
          reason: report.reason,
          details: report.details,
          status: report.status,
          timeAgo: report.timeAgo,
          reporterId: report.reporterId,
          reporterHandle: report.reporterHandle,
          targetHandle: preview.isNotEmpty ? preview : topicTitle,
          targetForumId: forumId,
          targetTopicId: reply?['topic_id'] as String?,
          authorProfileId: reply?['author_id'] as String?,
        );
      default:
        return report;
    }
  }

  ForumTopic _topicFromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.parse(row['created_at'] as String);
    final rejectedAt = row['rejected_at'] == null
        ? null
        : DateTime.parse(row['rejected_at'] as String);
    final historyAt = rejectedAt ?? createdAt;
    return ForumTopic(
      id: row['id'] as String,
      forumId: row['forum_id'] as String,
      title: row['title'] as String,
      excerpt: row['excerpt'] as String,
      body: row['body'] as String,
      authorHandle: row['author_handle'] as String,
      timeAgo: formatTimeAgo(historyAt),
      commentCount: row['comment_count'] as int? ?? 0,
      viewCount: row['view_count'] as int? ?? 0,
      isResolved: row['is_resolved'] as bool? ?? false,
      authorId: row['author_id'] as String?,
      authorAvatarUrl: _avatarUrlFromRow(row),
      authorVerified: _authorVerifiedFromRow(row),
      status: _statusFromRow(row['status'] as String?),
      isPinned: row['is_pinned'] as bool? ?? false,
      pinSortOrder: row['pin_sort_order'] as int? ?? 0,
      isSystem: row['is_system'] as bool? ?? false,
      isEditorial: row['is_editorial'] as bool? ?? false,
      viaAuthorId: row['via_author_id'] as String?,
      viaAuthorHandle: _viaAuthorHandleFromRow(row),
      seasonKey: row['season_key'] as String?,
      iconKey: row['icon_key'] as String?,
      iconImageUrl: row['icon_image_url'] as String?,
      coverImageUrl: row['cover_image_url'] as String?,
      coverImageCredit: (row['cover_image_credit'] as String?)?.trim().isNotEmpty ==
              true
          ? (row['cover_image_credit'] as String).trim()
          : null,
      galleryImageUrls: parseGalleryImageUrls(row['gallery_image_urls']),
      videoUrl: row['video_url'] as String?,
      videoPosterUrl: row['video_poster_url'] as String?,
      videoStatus: row['video_status'] as String?,
      videoProvider: row['video_provider'] as String?,
      videoExternalId: row['video_external_id'] as String?,
      isListed: row['is_listed'] as bool? ?? true,
      createdAt: createdAt,
      closeStatus: TopicCloseStatusX.fromDb(row['close_status'] as String?),
      isClosed: row['is_closed'] as bool? ?? false,
      editedAt: row['edited_at'] == null
          ? null
          : DateTime.parse(row['edited_at'] as String),
      rejectionReason: (row['rejection_reason'] as String?)?.trim(),
      rejectedAt: rejectedAt,
      calendarEventId: () {
        final id = (row['calendar_event_id'] as String?)?.trim();
        if (id == null || id.isEmpty) return null;
        return id;
      }(),
    );
  }

  String? _viaAuthorHandleFromRow(Map<String, dynamic> row) {
    if (row['is_editorial'] != true) return null;
    final profile = row['profiles'];
    if (profile is Map<String, dynamic>) {
      final handle = (profile['handle'] as String?)?.trim();
      if (handle != null && handle.isNotEmpty) return handle;
    }
    return null;
  }

  ModerationReport _reportFromRow(Map<String, dynamic> row) {
    final createdAt = DateTime.parse(row['created_at'] as String);
    final reporter = row['profiles'];
    String? reporterHandle;
    if (reporter is Map<String, dynamic>) {
      reporterHandle = reporter['handle'] as String?;
    }

    return ModerationReport(
      id: row['id'] as String,
      targetType: row['target_type'] as String,
      targetId: row['target_id'] as String,
      reason: row['reason'] as String,
      details: row['details'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
      timeAgo: formatTimeAgo(createdAt),
      reporterId: row['reporter_id'] as String,
      reporterHandle: reporterHandle,
    );
  }

  Future<void> setTopicStatus({
    required String topicId,
    required TopicStatus status,
    String? rejectionReason,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    final payload = <String, dynamic>{
      'status': _statusToDb(status),
    };
    if (status == TopicStatus.rejected) {
      final reason = rejectionReason?.trim();
      if (reason == null || reason.length < 3) {
        throw const TopicRejectionReasonRequiredException();
      }
      payload['rejection_reason'] = reason;
      payload['rejected_at'] = DateTime.now().toUtc().toIso8601String();
    } else if (status == TopicStatus.published) {
      payload['rejection_reason'] = null;
      payload['rejected_at'] = null;
    }

    await _client!.from('forum_topics').update(payload).eq('id', topicId);
  }

  /// Historial de rechazos, más recientes primero. [forumIds] filtra foros (moderador).
  Future<List<ForumTopic>> fetchRejectedTopics({
    int offset = 0,
    int limit = 20,
    List<String>? forumIds,
  }) async {
    if (_client == null) return [];
    if (forumIds != null && forumIds.isEmpty) return [];

    var query = _client!
        .from('forum_topics')
        .select(
          '*, profiles!author_id(avatar_url, display_name, handle, verified)',
        )
        .eq('status', 'rejected');

    if (forumIds != null) {
      query = query.inFilter('forum_id', forumIds);
    }

    final rows = await query
        .order('rejected_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows.map(_topicFromRow).toList();
  }

  /// Borra el MP4/HLS remoto (Stream o R2) de una editorial, si existe.
  Future<void> deleteEditorialVideoMedia({required String topicId}) async {
    if (_client == null) throw const AdminUnavailableException();
    try {
      await _client!.functions.invoke(
        'editorial-video-delete',
        body: {'topicId': topicId},
      );
    } catch (_) {
      // No bloqueamos el borrado del tema si falla el remoto;
      // se puede limpiar a mano en Cloudflare.
    }
  }

  /// Elimina un tema y sus respuestas. Requiere poder moderar el foro.
  /// Si es editorial con vídeo, intenta liberar Stream/R2 antes.
  Future<void> deleteTopic(String topicId) async {
    if (_client == null) throw const AdminUnavailableException();

    try {
      final row = await _client!
          .from('forum_topics')
          .select('is_editorial, video_provider, video_external_id')
          .eq('id', topicId)
          .maybeSingle();
      final isEditorial = row?['is_editorial'] == true;
      final hasRemote = (row?['video_external_id'] as String?)?.trim().isNotEmpty ==
          true;
      if (isEditorial && hasRemote) {
        await deleteEditorialVideoMedia(topicId: topicId);
      }
    } catch (_) {
      // Seguimos con el borrado del tema.
    }

    try {
      await _client!.rpc(
        'delete_forum_topic',
        params: {'p_topic_id': topicId},
      );
    } on PostgrestException catch (error) {
      final missing = error.code == 'PGRST202' ||
          error.message.contains('delete_forum_topic');
      if (!missing) throw const TopicDeleteFailedException();

      final deleted = await _client!
          .from('forum_topics')
          .delete()
          .eq('id', topicId)
          .select('id');
      if (deleted.isEmpty) throw const TopicDeleteFailedException();
    }
  }

  /// Compat: historial de rechazos.
  Future<void> deleteRejectedTopic(String topicId) => deleteTopic(topicId);

  Future<List<CalendarEvent>> fetchPendingCalendarEvents() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('calendar_events')
        .select('*, profiles!created_by(handle, display_name)')
        .eq('status', 'pending_review')
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map(_calendarEventFromRow).toList();
  }

  Future<List<ForumTopic>> fetchCloseRequestedTopics() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_topics')
        .select('*, profiles!author_id(avatar_url, verified)')
        .eq('close_status', 'close_requested')
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map(_topicFromRow).toList();
  }

  Future<void> setCalendarEventStatus({
    required String eventId,
    required CalendarEventStatus status,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('calendar_events')
        .update({'status': status.dbValue})
        .eq('id', eventId);
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    if (_client == null) throw const AdminUnavailableException();

    final deleted = await _client!
        .from('calendar_events')
        .delete()
        .eq('id', eventId)
        .select('id');

    if (deleted.isEmpty) {
      throw const CalendarEventDeleteFailedException();
    }
  }

  Future<void> approveTopicClose(String topicId) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('forum_topics')
        .update({
          'close_status': 'closed',
          'is_closed': true,
          'is_resolved': true,
        })
        .eq('id', topicId);
  }

  Future<void> rejectTopicCloseRequest(String topicId) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('forum_topics')
        .update({'close_status': 'open'})
        .eq('id', topicId);
  }

  Future<void> setTopicPinned({
    required String topicId,
    required bool isPinned,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('forum_topics')
        .update({'is_pinned': isPinned})
        .eq('id', topicId);
  }

  Future<void> closeTopic(String topicId) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('forum_topics')
        .update({
          'close_status': 'closed',
          'is_closed': true,
        })
        .eq('id', topicId);
  }

  Future<void> reopenTopic(String topicId) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('forum_topics')
        .update({
          'close_status': 'open',
          'is_closed': false,
        })
        .eq('id', topicId);
  }

  CalendarEvent _calendarEventFromRow(Map<String, dynamic> row) {
    final startsAt = DateTime.parse(row['starts_at'] as String).toLocal();
    final profile = row['profiles'];
    String? handle;
    if (profile is Map<String, dynamic>) {
      handle = profile['handle'] as String?;
    }
    return CalendarEvent(
      id: row['id'] as String,
      date: DateTime(startsAt.year, startsAt.month, startsAt.day),
      title: row['title'] as String,
      subtitle: row['subtitle'] as String? ?? '',
      type: EventType.fromDb(row['event_type'] as String?),
      dayLabel: row['day_label'] as String?,
      time: startsAt.hour > 0 || startsAt.minute > 0
          ? '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}'
          : null,
      location: (row['location'] as String?)?.trim().isEmpty == true
          ? null
          : row['location'] as String?,
      organizerLabel: (row['organizer_label'] as String?)?.trim().isEmpty == true
          ? null
          : row['organizer_label'] as String?,
      createdById: row['created_by'] as String?,
      publisherHandle: handle,
      customIconUrl: row['custom_icon_url'] as String?,
      coverImageUrl: row['cover_image_url'] as String?,
      coverImageCredit: (row['cover_image_credit'] as String?)?.trim().isNotEmpty ==
              true
          ? (row['cover_image_credit'] as String).trim()
          : null,
      status: CalendarEventStatusX.fromDb(row['status'] as String?),
      spanUntil: () {
        final raw = row['span_until'];
        if (raw == null) return null;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed == null) return null;
        final local = parsed.isUtc ? parsed.toLocal() : parsed;
        return DateTime(local.year, local.month, local.day);
      }(),
    );
  }

  Future<List<ForumCategory>> fetchPillars() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_pillars')
        .select()
        .order('sort_order', ascending: true);

    return rows.map(_pillarFromRow).toList();
  }

  Future<void> updatePillar({
    required String pillarId,
    bool? isEnabled,
    bool? isActive,
    String? name,
    String? description,
    String? iconKey,
    String? iconImageUrl,
    String? coverImageUrl,
    String? aboutTagline,
    String? aboutBody,
    String? forumRules,
    int? sortOrder,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    final patch = <String, dynamic>{};
    if (isEnabled != null) patch['is_enabled'] = isEnabled;
    if (isActive != null) patch['is_active'] = isActive;
    if (name != null) patch['name'] = name.trim();
    if (description != null) patch['description'] = description.trim();
    if (iconKey != null) patch['icon_key'] = iconKey;
    if (iconImageUrl != null) {
      patch['icon_image_url'] = iconImageUrl.trim().isEmpty
          ? null
          : iconImageUrl.trim();
    }
    if (coverImageUrl != null) {
      patch['cover_image_url'] = coverImageUrl.trim().isEmpty
          ? null
          : coverImageUrl.trim();
    }
    if (aboutTagline != null) {
      patch['about_tagline'] = aboutTagline.trim().isEmpty
          ? null
          : aboutTagline.trim();
    }
    if (aboutBody != null) {
      patch['about_body'] =
          aboutBody.trim().isEmpty ? null : aboutBody.trim();
    }
    if (forumRules != null) {
      patch['forum_rules'] =
          forumRules.trim().isEmpty ? null : forumRules.trim();
    }
    if (sortOrder != null) patch['sort_order'] = sortOrder;
    if (patch.isEmpty) return;

    await _client!.from('forum_pillars').update(patch).eq('id', pillarId);
  }

  Future<String> uploadPillarIcon({
    required String pillarId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    if (bytes.length > _maxPillarIconBytes) {
      throw const PillarIconTooLargeException();
    }

    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final prepared = await prepareImageUploadAsync(
      rawBytes: bytes,
      extension: extension,
      contentType: mimeType,
      maxBytes: ImageUploadLimits.pillarIconMaxBytes,
      maxSide: ImageUploadLimits.pillarIconMaxSide,
    );
    final path = '$pillarId/icon.${prepared.extension}';

    await _client!.storage
        .from(_forumIconsBucket)
        .uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: prepared.contentType,
          ),
        );

    final publicUrl = _client!.storage
        .from(_forumIconsBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadPillarCover({
    required String pillarId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    if (bytes.length > _maxPillarCoverBytes) {
      throw const PillarCoverTooLargeException();
    }

    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final prepared = await prepareImageUploadAsync(
      rawBytes: bytes,
      extension: extension,
      contentType: mimeType,
      maxBytes: ImageUploadLimits.pillarCoverMaxBytes,
      maxSide: ImageUploadLimits.pillarCoverMaxSide,
    );
    final path = '$pillarId/cover.${prepared.extension}';

    await _client!.storage
        .from(_forumCoversBucket)
        .uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: prepared.contentType,
          ),
        );

    final publicUrl = _client!.storage
        .from(_forumCoversBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> fetchAppConfig(String key) async {
    if (_client == null) return null;

    final row = await _client!
        .from('app_config')
        .select('value')
        .eq('key', key)
        .maybeSingle();

    final value = row?['value'] as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> setAppConfig(String key, String value) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!.from('app_config').upsert({
      'key': key,
      'value': value.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String> uploadForumsListHero({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (_client == null) throw const AdminUnavailableException();
    if (bytes.length > _maxPillarCoverBytes) {
      throw const PillarCoverTooLargeException();
    }

    final extension = switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final prepared = await prepareImageUploadAsync(
      rawBytes: bytes,
      extension: extension,
      contentType: mimeType,
      maxBytes: ImageUploadLimits.pillarCoverMaxBytes,
      maxSide: ImageUploadLimits.pillarCoverMaxSide,
    );
    final path = '_global/forums-hero.${prepared.extension}';

    await _client!.storage
        .from(_forumCoversBucket)
        .uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: prepared.contentType,
          ),
        );

    final publicUrl = _client!.storage
        .from(_forumCoversBucket)
        .getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<ForumCategory> createPillar({
    required String id,
    required String name,
    required String description,
    String iconKey = 'church',
    int? sortOrder,
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    final trimmedId = id.trim().toLowerCase();
    final trimmedName = name.trim();
    if (trimmedId.isEmpty || trimmedName.isEmpty) {
      throw ArgumentError('El id y el nombre del foro son obligatorios.');
    }

    var nextOrder = sortOrder;
    if (nextOrder == null) {
      final pillars = await fetchPillars();
      nextOrder = pillars.isEmpty
          ? 1
          : pillars.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    }

    final row = await _client!
        .from('forum_pillars')
        .insert({
          'id': trimmedId,
          'name': trimmedName,
          'description': description.trim(),
          'icon_key': iconKey,
          'sort_order': nextOrder,
          'is_enabled': true,
          'is_active': false,
        })
        .select()
        .single();

    return _pillarFromRow(row);
  }

  Future<void> deletePillar(String pillarId) async {
    if (_client == null) throw const AdminUnavailableException();
    await _client!.from('forum_pillars').delete().eq('id', pillarId);
  }

  ForumCategory _pillarFromRow(Map<String, dynamic> row) {
    final enabled = row['is_enabled'] as bool? ?? true;
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
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toLocal()
          : null,
      sortOrder: row['sort_order'] as int? ?? 0,
      topicCount: row['topic_count'] as int? ?? 0,
      messageCount: row['message_count'] as int? ?? 0,
      lastMessageAgo: enabled ? '—' : '—',
      lastTopicId: row['last_topic_id'] as String?,
      lastTopicTitle: row['last_topic_title'] as String?,
      lastTopicExcerpt: row['last_topic_excerpt'] as String?,
      isEnabled: enabled,
      isActive: row['is_active'] as bool? ?? false,
      lockedLabel: row['locked_label'] as String?,
    );
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

  TopicStatus _statusFromRow(String? raw) {
    return switch (raw) {
      'pending' => TopicStatus.pending,
      'rejected' => TopicStatus.rejected,
      _ => TopicStatus.published,
    };
  }

  String _statusToDb(TopicStatus status) {
    return switch (status) {
      TopicStatus.pending => 'pending',
      TopicStatus.rejected => 'rejected',
      TopicStatus.published => 'published',
    };
  }
}

class SignupDayCount {
  const SignupDayCount({required this.date, required this.count});

  final String date;
  final int count;
}

class SignupPulse {
  const SignupPulse({
    required this.today,
    required this.yesterday,
    required this.last7,
    required this.last30,
    required this.total,
    required this.cofrades,
    required this.hermandades,
    required this.days,
  });

  final int today;
  final int yesterday;
  final int last7;
  final int last30;
  final int total;
  final int cofrades;
  final int hermandades;
  final List<SignupDayCount> days;

  String get todayHint {
    final delta = today - yesterday;
    if (delta == 0) return 'Igual que ayer';
    if (delta > 0) return '+$delta respecto a ayer';
    return '$delta respecto a ayer';
  }

  factory SignupPulse.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final days = <SignupDayCount>[];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final date = map['date']?.toString() ?? '';
        if (date.isEmpty) continue;
        days.add(
          SignupDayCount(
            date: date,
            count: (map['count'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return SignupPulse(
      today: (json['today'] as num?)?.toInt() ?? 0,
      yesterday: (json['yesterday'] as num?)?.toInt() ?? 0,
      last7: (json['last7'] as num?)?.toInt() ?? 0,
      last30: (json['last30'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      cofrades: (json['cofrades'] as num?)?.toInt() ?? 0,
      hermandades: (json['hermandades'] as num?)?.toInt() ?? 0,
      days: days,
    );
  }
}

class XIngestSettings {
  const XIngestSettings({
    required this.enabled,
    required this.intervalMinutes,
    required this.maxPostsPerAccount,
    this.lastRunAt,
    this.lastRunStatus,
    this.lastRunError,
    this.lastRunNewPosts = 0,
    this.lastRunAccounts = 0,
    this.lastRunForced = false,
  });

  final bool enabled;
  final int intervalMinutes;
  final int maxPostsPerAccount;
  final DateTime? lastRunAt;
  final String? lastRunStatus;
  final String? lastRunError;
  final int lastRunNewPosts;
  final int lastRunAccounts;
  final bool lastRunForced;

  factory XIngestSettings.fromJson(Map<String, dynamic> json) {
    return XIngestSettings(
      enabled: json['enabled'] == true,
      intervalMinutes: (json['interval_minutes'] as num?)?.toInt() ?? 60,
      maxPostsPerAccount:
          (json['max_posts_per_account'] as num?)?.toInt() ?? 8,
      lastRunAt: DateTime.tryParse(json['last_run_at']?.toString() ?? ''),
      lastRunStatus: json['last_run_status']?.toString(),
      lastRunError: json['last_run_error']?.toString(),
      lastRunNewPosts: (json['last_run_new_posts'] as num?)?.toInt() ?? 0,
      lastRunAccounts: (json['last_run_accounts'] as num?)?.toInt() ?? 0,
      lastRunForced: json['last_run_forced'] == true,
    );
  }
}

class XIngestAccount {
  const XIngestAccount({
    required this.id,
    required this.topicId,
    required this.handle,
    required this.ingestEnabled,
    this.xUserId,
    this.sinceId,
    this.lastError,
    this.lastPulledAt,
    this.lastCapped = false,
    this.topicTitle,
  });

  final String id;
  final String topicId;
  final String handle;
  final bool ingestEnabled;
  final String? xUserId;
  final String? sinceId;
  final String? lastError;
  final DateTime? lastPulledAt;
  final bool lastCapped;
  final String? topicTitle;

  String get handleLabel => '@$handle';

  factory XIngestAccount.fromJson(Map<String, dynamic> json) {
    final topic = json['forum_topics'];
    String? title;
    if (topic is Map) {
      title = topic['title']?.toString();
    }
    return XIngestAccount(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      handle: json['handle'] as String,
      ingestEnabled: json['ingest_enabled'] != false,
      xUserId: json['x_user_id']?.toString(),
      sinceId: json['since_id']?.toString(),
      lastError: json['last_error']?.toString(),
      lastPulledAt: DateTime.tryParse(json['last_pulled_at']?.toString() ?? ''),
      lastCapped: json['last_capped'] == true,
      topicTitle: title,
    );
  }
}

class XIngestDraft {
  const XIngestDraft({
    required this.id,
    required this.accountId,
    required this.topicId,
    required this.handle,
    required this.xPostId,
    required this.body,
    required this.status,
    required this.suggestedCategory,
    this.sourceUrl,
    this.media = const [],
    this.postedAt,
    this.topicTitle,
  });

  final String id;
  final String accountId;
  final String topicId;
  final String handle;
  final String xPostId;
  final String body;
  final String status;
  final String suggestedCategory;
  final String? sourceUrl;
  final List<Map<String, dynamic>> media;
  final DateTime? postedAt;
  final String? topicTitle;

  String? get imageUrl {
    for (final item in media) {
      final type = item['type']?.toString();
      final url = item['url']?.toString();
      if ((type == 'photo' || type == 'image') &&
          url != null &&
          url.isNotEmpty) {
        return url;
      }
    }
    for (final item in media) {
      final preview = item['previewUrl']?.toString() ?? item['url']?.toString();
      if (preview != null && preview.isNotEmpty) return preview;
    }
    return null;
  }

  factory XIngestDraft.fromJson(Map<String, dynamic> json) {
    final topic = json['forum_topics'];
    String? title;
    if (topic is Map) {
      title = topic['title']?.toString();
    }
    final rawMedia = json['media'];
    final media = <Map<String, dynamic>>[];
    if (rawMedia is List) {
      for (final item in rawMedia) {
        if (item is Map) {
          media.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return XIngestDraft(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      topicId: json['topic_id'] as String,
      handle: json['handle'] as String,
      xPostId: json['x_post_id'] as String,
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      suggestedCategory: json['suggested_category'] as String? ?? 'noticia',
      sourceUrl: json['source_url']?.toString(),
      media: media,
      postedAt: DateTime.tryParse(json['posted_at']?.toString() ?? ''),
      topicTitle: title,
    );
  }
}

class XIngestException implements Exception {
  const XIngestException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AdminUnavailableException implements Exception {
  const AdminUnavailableException();
}

class TopicRejectionReasonRequiredException implements Exception {
  const TopicRejectionReasonRequiredException();
}

class TopicDeleteFailedException implements Exception {
  const TopicDeleteFailedException();
}

class PillarIconTooLargeException implements Exception {
  const PillarIconTooLargeException();
}

class PillarCoverTooLargeException implements Exception {
  const PillarCoverTooLargeException();
}

AdminRepository createAdminRepository() {
  return AdminRepository(client: SupabaseBootstrap.client);
}
