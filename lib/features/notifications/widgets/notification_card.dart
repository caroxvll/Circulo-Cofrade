import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/app_notification.dart';
import '../notifications_design.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NotificationsDesign.cardRadius),
        child: Ink(
          decoration: NotificationsDesign.cardDecoration(unread: unread),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  Container(
                    width: 3,
                    height: 44,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                _NotificationLeading(notification: notification),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTypography.titleLarge(
                                color: AppColors.textPrimary,
                              ).copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notification.timeAgo,
                            style: NotificationsDesign.meta().copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.subtitle,
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(
                          height: 1.35,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationLeading extends StatelessWidget {
  const _NotificationLeading({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    if (notification.avatarIcon != null) {
      return CofradeoAvatar(
        icon: notification.avatarIcon,
        size: 44,
        backgroundColor: AppColors.burgundyDark,
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: notification.badgeBackgroundColor ?? AppColors.burgundy,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.2),
        ),
      ),
      child: Icon(
        notification.badgeIcon ?? Icons.notifications_outlined,
        color: AppColors.goldPale,
        size: 22,
      ),
    );
  }
}
