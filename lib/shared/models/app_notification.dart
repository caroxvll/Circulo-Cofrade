import 'package:flutter/material.dart';

enum AppNotificationKind {
  hashtagActivity,
  topicActivity,
  userPost,
  mention,
  newFollower,
  calendarEvent,
  topicPendingReview,
  newReport,
  topicPublished,
  topicRejected,
  accountSuspended,
  accountReactivated,
  system,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.kind,
    this.isRead = false,
    this.avatarIcon,
    this.badgeIcon,
    this.badgeBackgroundColor,
    this.forumId,
    this.topicId,
    this.replyId,
    this.profileId,
    this.route,
  });

  final String id;
  final String title;
  final String subtitle;
  final String timeAgo;
  final AppNotificationKind kind;
  final bool isRead;
  final IconData? avatarIcon;
  final IconData? badgeIcon;
  final Color? badgeBackgroundColor;
  final String? forumId;
  final String? topicId;
  final String? replyId;
  final String? profileId;
  final String? route;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      subtitle: subtitle,
      timeAgo: timeAgo,
      kind: kind,
      isRead: isRead ?? this.isRead,
      avatarIcon: avatarIcon,
      badgeIcon: badgeIcon,
      badgeBackgroundColor: badgeBackgroundColor,
      forumId: forumId,
      topicId: topicId,
      replyId: replyId,
      profileId: profileId,
      route: route,
    );
  }
}
