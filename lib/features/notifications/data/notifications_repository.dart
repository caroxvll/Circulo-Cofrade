import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/app_notification.dart';
import 'mock_notifications.dart';

class NotificationsRepository {
  NotificationsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isAvailable => _client != null;

  Future<List<AppNotification>> fetchForUser(String userId) async {
    if (_client == null) return List.from(mockNotifications);

    final rows = await _client!
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    if (rows.isEmpty) return [];

    return rows.map(_fromRow).toList();
  }

  Future<void> markAllRead(String userId) async {
    if (_client == null) return;

    await _client!
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
  }

  Future<void> markRead(String userId, String notificationId) async {
    if (_client == null) return;

    await _client!
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .eq('id', notificationId);
  }

  Future<void> delete(String userId, String notificationId) async {
    if (_client == null) return;

    await _client!
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('id', notificationId);
  }

  Future<void> deleteAll(String userId) async {
    if (_client == null) return;

    await _client!.from('notifications').delete().eq('user_id', userId);
  }

  AppNotification _fromRow(Map<String, dynamic> row) {
    final payload = row['payload'] as Map<String, dynamic>? ?? {};
    final type = row['type'] as String? ?? 'system';
    final createdAt = DateTime.parse(row['created_at'] as String);
    final readAt = row['read_at'];

    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String? ?? '',
      timeAgo: _formatTimeAgo(createdAt),
      kind: _kindFromType(type),
      isRead: readAt != null,
      forumId: _payloadString(payload, 'forumId'),
      topicId: _payloadString(payload, 'topicId'),
      replyId: _payloadString(payload, 'replyId'),
      profileId: _payloadString(payload, 'profileId'),
      route: _payloadString(payload, 'route'),
      avatarIcon: _iconForType(type),
      badgeIcon: type == 'mention' ? Icons.alternate_email : null,
      badgeBackgroundColor:
          type == 'mention' ? const Color(0xFFC44B4B) : null,
    );
  }

  AppNotificationKind _kindFromType(String type) {
    return switch (type) {
      'hashtag_activity' => AppNotificationKind.hashtagActivity,
      'topic_activity' => AppNotificationKind.topicActivity,
      'user_post' || 'user_reply' => AppNotificationKind.userPost,
      'mention' => AppNotificationKind.mention,
      'new_follower' => AppNotificationKind.newFollower,
      'calendar' => AppNotificationKind.calendarEvent,
      'topic_pending_review' => AppNotificationKind.topicPendingReview,
      'new_report' => AppNotificationKind.newReport,
      'topic_published' => AppNotificationKind.topicPublished,
      'topic_rejected' => AppNotificationKind.topicRejected,
      'account_suspended' => AppNotificationKind.accountSuspended,
      'account_reactivated' => AppNotificationKind.accountReactivated,
      _ => AppNotificationKind.system,
    };
  }

  IconData? _iconForType(String type) {
    return switch (type) {
      'hashtag_activity' => Icons.tag,
      'topic_activity' => Icons.forum_outlined,
      'user_post' || 'user_reply' => Icons.chat_bubble_outline,
      'new_follower' => Icons.person_add_outlined,
      'mention' => Icons.alternate_email,
      'calendar' => Icons.calendar_month_outlined,
      'topic_pending_review' => Icons.gavel_outlined,
      'new_report' => Icons.flag_outlined,
      'topic_published' => Icons.check_circle_outline,
      'topic_rejected' => Icons.cancel_outlined,
      'account_suspended' => Icons.block_outlined,
      'account_reactivated' => Icons.check_circle_outline,
      _ => Icons.notifications_outlined,
    };
  }

  String _formatTimeAgo(DateTime dateTime) {
    final s = formatTimeAgo(dateTime);
    if (s == 'ahora') return 'Ahora';
    return s[0].toUpperCase() + s.substring(1);
  }

  String? _payloadString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}

NotificationsRepository createNotificationsRepository() {
  return NotificationsRepository(client: SupabaseBootstrap.client);
}
