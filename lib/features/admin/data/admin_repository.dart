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

  Future<List<ForumTopic>> fetchPendingTopics() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_topics')
        .select('*, profiles!author_id(avatar_url, verified)')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map(_topicFromRow).toList();
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
      seasonKey: row['season_key'] as String?,
      iconKey: row['icon_key'] as String?,
      coverImageUrl: row['cover_image_url'] as String?,
      isListed: row['is_listed'] as bool? ?? true,
      createdAt: createdAt,
      closeStatus: TopicCloseStatusX.fromDb(row['close_status'] as String?),
      isClosed: row['is_closed'] as bool? ?? false,
      editedAt: row['edited_at'] == null
          ? null
          : DateTime.parse(row['edited_at'] as String),
      rejectionReason: (row['rejection_reason'] as String?)?.trim(),
      rejectedAt: rejectedAt,
    );
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
        .select('*, profiles!author_id(avatar_url, verified)')
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

  /// Elimina un tema (y respuestas por cascade). Requiere poder moderar el foro.
  Future<void> deleteTopic(String topicId) async {
    if (_client == null) throw const AdminUnavailableException();

    final deleted = await _client!
        .from('forum_topics')
        .delete()
        .eq('id', topicId)
        .select('id');

    if (deleted.isEmpty) {
      throw const TopicDeleteFailedException();
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
      status: CalendarEventStatusX.fromDb(row['status'] as String?),
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
