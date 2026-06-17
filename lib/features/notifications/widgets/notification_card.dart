import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/app_notification.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  static const _cardColor = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: notification.isRead
                ? null
                : Border.all(
                    color: AppColors.burgundy.withValues(alpha: 0.45),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                              color: AppColors.textOnDark,
                            ).copyWith(fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notification.timeAgo,
                          style: AppTypography.labelSmall(
                            color: AppColors.textMuted,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.subtitle,
                      style: AppTypography.bodyMedium(
                        color: AppColors.goldLight,
                      ).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
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
      ),
      child: Icon(
        notification.badgeIcon ?? Icons.notifications_outlined,
        color: AppColors.goldPale,
        size: 22,
      ),
    );
  }
}
