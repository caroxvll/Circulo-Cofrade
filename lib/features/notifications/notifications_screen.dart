import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/screen_title_row.dart';
import '../../shared/models/app_notification.dart';
import '../forums/utils/forum_navigation.dart';
import '../forums/forums_provider.dart';
import 'notifications_provider.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    await ref.read(notificationsProvider.notifier).silentRefresh();
    await ref.read(notificationsProvider.notifier).markAllRead();
  }

  Future<void> _onNotificationTap(AppNotification notification) async {
    final notifier = ref.read(notificationsProvider.notifier);

    if (notification.forumId != null && notification.topicId != null) {
      invalidateTopicData(
        ref,
        forumId: notification.forumId!,
        topicId: notification.topicId!,
      );
      await notifier.dismiss(notification.id);
      if (!mounted) return;
      final fromApproval =
          notification.kind == AppNotificationKind.topicPublished;
      final replyId = notification.replyId;
      final suffix = fromApproval
          ? '?aprobado=1'
          : replyId != null && replyId.isNotEmpty
              ? '?reply=${Uri.encodeComponent(replyId)}'
              : '';
      openForumTopic(
        context,
        forumId: notification.forumId!,
        topicId: notification.topicId!,
        querySuffix: suffix,
      );
      return;
    }

    if (notification.kind == AppNotificationKind.newReport) {
      await notifier.dismiss(notification.id);
      if (!mounted) return;
      context.go('/perfil/junta');
      return;
    }

    if (notification.profileId != null) {
      await notifier.dismiss(notification.id);
      if (!mounted) return;
      context.go('/perfil/usuario/${notification.profileId}');
      return;
    }

    final route = notification.route;
    await notifier.dismiss(notification.id);
    if (!mounted) return;
    if (route != null) {
      context.go(route);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar notificaciones'),
        content: const Text(
          '¿Quieres eliminar todas las notificaciones de la bandeja?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(notificationsProvider.notifier).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return SafeArea(
      bottom: false,
      child: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _NotificationsList(
          notifications: const [],
          onTap: _onNotificationTap,
          onDismiss: (n) =>
              ref.read(notificationsProvider.notifier).dismiss(n.id),
          onMarkAllRead: () =>
              ref.read(notificationsProvider.notifier).markAllRead(),
          onClearAll: _confirmClear,
        ),
        data: (notifications) => RefreshIndicator(
          onRefresh: () =>
              ref.read(notificationsProvider.notifier).silentRefresh(),
          child: _NotificationsList(
            notifications: notifications,
            onTap: _onNotificationTap,
            onDismiss: (n) =>
                ref.read(notificationsProvider.notifier).dismiss(n.id),
            onMarkAllRead: () =>
                ref.read(notificationsProvider.notifier).markAllRead(),
            onClearAll: _confirmClear,
          ),
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.notifications,
    required this.onTap,
    required this.onDismiss,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  final List<AppNotification> notifications;
  final Future<void> Function(AppNotification notification) onTap;
  final void Function(AppNotification notification) onDismiss;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final hasUnread = notifications.any((n) => !n.isRead);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          sliver: SliverToBoxAdapter(
            child: ScreenTitleRow(
              title: 'Notificaciones',
              trailing: [
                if (notifications.isNotEmpty) ...[
                  if (hasUnread)
                    TextButton(
                      onPressed: onMarkAllRead,
                      child: Text(
                        'Marcar leídas',
                        style: AppTypography.labelSmall(
                          color: AppColors.burgundy,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: onClearAll,
                    child: Text(
                      'Limpiar',
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (notifications.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Text(
                'No tienes notificaciones.',
                style: AppTypography.bodyMedium(),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => onDismiss(notification),
                  child: NotificationCard(
                    notification: notification,
                    onTap: () => onTap(notification),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
