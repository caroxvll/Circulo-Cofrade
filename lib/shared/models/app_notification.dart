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
  replyReaction,
  cofradeRankUp,
  newsPublished,
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
    this.officialCategory,
    this.eventId,
    this.eventStartsAt,
    this.topicTitle,
    this.rejectionReason,
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
  final String? officialCategory;
  final String? eventId;
  final DateTime? eventStartsAt;
  final String? topicTitle;
  final String? rejectionReason;

  AppNotification copyWith({bool? isRead, String? subtitle}) {
    return AppNotification(
      id: id,
      title: title,
      subtitle: subtitle ?? this.subtitle,
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
      officialCategory: officialCategory,
      eventId: eventId,
      eventStartsAt: eventStartsAt,
      topicTitle: topicTitle,
      rejectionReason: rejectionReason,
    );
  }
}
