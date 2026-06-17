import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/forum.dart';
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

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<List<ForumTopic>> fetchPendingTopics() async {
    if (_client == null) return [];

    final rows = await _client!
        .from('forum_topics')
        .select('*, profiles!author_id(avatar_url)')
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

    await _client!.from('profiles').update({
      'suspended_at': null,
      'suspended_reason': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', profileId);
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
          .select('id, content, topic_id, author_id, forum_topics(forum_id, title)')
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
        final topicTitle =
            topicMeta is Map<String, dynamic> ? topicMeta['title'] as String? : null;
        final forumId =
            topicMeta is Map<String, dynamic> ? topicMeta['forum_id'] as String? : null;
        final content = reply?['content'] as String? ?? '';
        final preview = content.length > 48 ? '${content.substring(0, 45)}…' : content;
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
    return ForumTopic(
      id: row['id'] as String,
      forumId: row['forum_id'] as String,
      title: row['title'] as String,
      excerpt: row['excerpt'] as String,
      body: row['body'] as String,
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
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    await _client!
        .from('forum_topics')
        .update({'status': _statusToDb(status)})
        .eq('id', topicId);
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
  }) async {
    if (_client == null) throw const AdminUnavailableException();

    final patch = <String, dynamic>{};
    if (isEnabled != null) patch['is_enabled'] = isEnabled;
    if (isActive != null) patch['is_active'] = isActive;
    if (patch.isEmpty) return;

    await _client!.from('forum_pillars').update(patch).eq('id', pillarId);
  }

  ForumCategory _pillarFromRow(Map<String, dynamic> row) {
    final enabled = row['is_enabled'] as bool? ?? true;
    return ForumCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      icon: forumIconFromKey(row['icon_key'] as String?),
      headerIcon: forumIconFromKey(row['icon_key'] as String?),
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

AdminRepository createAdminRepository() {
  return AdminRepository(client: SupabaseBootstrap.client);
}
