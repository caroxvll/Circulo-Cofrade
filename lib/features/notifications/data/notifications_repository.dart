import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/models/app_notification.dart';
import '../../calendar/utils/calendar_notification_navigation.dart';
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

    return _groupReplyReactionNotifications(
      rows.map(_fromRow).toList(),
    );
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

  Future<void> deleteUnreadReplyReactionsForReply(
    String userId,
    String replyId,
  ) async {
    if (_client == null) return;

    await _client!
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('type', 'reply_reaction')
        .filter('read_at', 'is', null)
        .filter('payload->>replyId', 'eq', replyId);
  }

  Future<void> markReadReplyReactionGroup(
    String userId,
    String replyId,
  ) async {
    if (_client == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    await _client!
        .from('notifications')
        .update({'read_at': now})
        .eq('user_id', userId)
        .eq('type', 'reply_reaction')
        .filter('read_at', 'is', null)
        .filter('payload->>replyId', 'eq', replyId);
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
      officialCategory: _payloadString(payload, 'officialCategory'),
      eventId: _payloadString(payload, 'eventId'),
      eventStartsAt: parseNotificationEventStartsAt(payload['startsAt']),
      topicTitle: _payloadString(payload, 'topicTitle'),
      rejectionReason: _payloadString(payload, 'rejectionReason'),
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
      'reply_reaction' => AppNotificationKind.replyReaction,
      'cofrade_rank_up' => AppNotificationKind.cofradeRankUp,
      'news_published' => AppNotificationKind.newsPublished,
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
      'reply_reaction' => Icons.add_reaction_outlined,
      'cofrade_rank_up' => Icons.military_tech_outlined,
      'news_published' => Icons.newspaper_outlined,
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

  /// Agrupa avisos duplicados de reacción (mismo comentario, sin leer).
  List<AppNotification> _groupReplyReactionNotifications(
    List<AppNotification> notifications,
  ) {
    final groupedReplyIds = <String>{};
    final result = <AppNotification>[];

    for (final notification in notifications) {
      if (notification.kind != AppNotificationKind.replyReaction ||
          notification.isRead ||
          notification.replyId == null) {
        result.add(notification);
        continue;
      }

      final replyId = notification.replyId!.toLowerCase();
      if (groupedReplyIds.contains(replyId)) continue;
      groupedReplyIds.add(replyId);

      final siblings = notifications
          .where(
            (n) =>
                n.kind == AppNotificationKind.replyReaction &&
                !n.isRead &&
                n.replyId?.toLowerCase() == replyId,
          )
          .toList();

      if (siblings.length <= 1) {
        result.add(notification);
        continue;
      }

      result.add(_mergeReactionNotifications(siblings));
    }

    return result;
  }

  AppNotification _mergeReactionNotifications(List<AppNotification> group) {
    final latest = group.first;
    final first = group.last;
    final count = group.length;

    if (count == 2) {
      return latest.copyWith(
        subtitle: '${first.title} y ${latest.title} reaccionaron a tu comentario',
      );
    }

    return latest.copyWith(
      subtitle: '$count personas reaccionaron a tu comentario',
    );
  }
}

NotificationsRepository createNotificationsRepository() {
  return NotificationsRepository(client: SupabaseBootstrap.client);
}
