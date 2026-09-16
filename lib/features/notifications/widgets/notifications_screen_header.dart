import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/calendar_quick_access_button.dart';
import '../notifications_design.dart';

class NotificationsScreenHeader extends StatelessWidget {
  const NotificationsScreenHeader({
    super.key,
    required this.unreadCount,
    required this.totalCount,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  final int unreadCount;
  final int totalCount;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'NOTIFICACIONES',
                style: NotificationsDesign.screenTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const CalendarQuickAccessButton(),
          ],
        ),
        if (totalCount > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  unreadCount > 0
                      ? '$unreadCount sin leer · $totalCount en total'
                      : '$totalCount en la bandeja',
                  style: NotificationsDesign.meta(),
                ),
              ),
              if (unreadCount > 0)
                TextButton(
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Marcar leídas', style: NotificationsDesign.actionLabel()),
                ),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Limpiar', style: NotificationsDesign.actionLabel()),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class NotificationsEmptyState extends StatelessWidget {
  const NotificationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: NotificationsDesign.cardDecoration(unread: false),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldPale.withValues(alpha: 0.45),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.goldDark,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bandeja al día',
            style: NotificationsDesign.compactScreenTitle().copyWith(
              fontSize: 20,
              color: AppColors.burgundy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando alguien te mencione, reaccione, publique en un hilo que '
            'sigues o haya novedades del calendario cofrade, lo verás aquí.',
            style: NotificationsDesign.meta().copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
