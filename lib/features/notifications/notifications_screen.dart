import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/cofradeo_error_panel.dart';
import '../../core/widgets/cofradeo_skeleton.dart';
import '../../shared/models/app_notification.dart';
import '../../core/utils/forum_topic_query.dart';
import '../forums/utils/forum_navigation.dart';
import '../forums/forums_provider.dart';
import '../forums/widgets/forums_beige_background.dart';
import '../calendar/utils/calendar_notification_navigation.dart';
import '../calendar/calendar_provider.dart';
import '../search/follows_provider.dart';
import 'notifications_design.dart';
import 'notifications_provider.dart';
import 'widgets/notification_card.dart';
import 'widgets/notifications_screen_header.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _busyFollowRequestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    await ref.read(notificationsProvider.notifier).silentRefresh();
  }

  Future<void> _openCalendarNotification(AppNotification notification) async {
    if (!mounted) return;
    // Ir ya al calendario; el foco se resuelve en segundo plano.
    context.go('/calendario');
    final focus = await buildCalendarFocusFromNotification(
      repo: ref.read(calendarRepositoryProvider),
      eventId: notification.eventId,
      startsAt: notification.eventStartsAt,
    );
    if (focus != null) {
      ref.read(calendarFocusRequestProvider.notifier).setFocus(focus);
    }
  }

  Future<void> _onNotificationTap(AppNotification notification) async {
    final notifier = ref.read(notificationsProvider.notifier);

    if (notification.kind == AppNotificationKind.ssLiveOfficial) {
      final route = notification.route ??
          (notification.forumId != null && notification.topicId != null
              ? '/foros/${notification.forumId}/tema/${notification.topicId}'
              : null);
      if (!mounted) return;
      if (route != null) {
        context.go(route);
      }
      unawaited(notifier.dismiss(notification.id));
      return;
    }

    if (notification.kind == AppNotificationKind.topicRejected) {
      if (!mounted) return;
      // Marcar leída en background; no bloquear el sheet.
      unawaited(notifier.markRead(notification.id));
      await _showTopicRejectedSheet(notification);
      return;
    }

    if (notification.forumId != null && notification.topicId != null) {
      // Solo el hilo: no refetch de toda la lista del foro.
      ref.invalidate(
        forumTopicProvider(
          ForumTopicKey(
            forumId: notification.forumId!,
            topicId: notification.topicId!,
          ),
        ),
      );
      final fromApproval =
          notification.kind == AppNotificationKind.topicPublished;
      final suffix = buildForumTopicQuery(
        approved: fromApproval,
        section: notification.forumId == 'hermandades'
            ? notification.officialCategory
            : null,
        replyId: notification.replyId,
      );
      if (!mounted) return;
      openForumTopic(
        context,
        forumId: notification.forumId!,
        topicId: notification.topicId!,
        querySuffix: suffix,
      );
      unawaited(notifier.dismiss(notification.id));
      return;
    }

    if (notification.kind == AppNotificationKind.cofradeRankUp) {
      if (!mounted) return;
      context.go('/perfil');
      unawaited(notifier.dismiss(notification.id));
      return;
    }

    if (notification.kind == AppNotificationKind.newReport) {
      if (!mounted) return;
      context.go('/perfil/junta');
      unawaited(notifier.dismiss(notification.id));
      return;
    }

    // Solicitud pendiente: ver perfil sin descartar la notif (aún se puede aceptar).
    if (notification.kind == AppNotificationKind.followRequest &&
        notification.profileId != null) {
      if (!mounted) return;
      unawaited(notifier.markRead(notification.id));
      context.go('/perfil/usuario/${notification.profileId}');
      return;
    }

    if (notification.profileId != null) {
      if (!mounted) return;
      context.go('/perfil/usuario/${notification.profileId}');
      unawaited(notifier.dismiss(notification.id));
      return;
    }

    if (notification.kind == AppNotificationKind.calendarEvent ||
        notification.eventId != null ||
        notification.route == '/calendario') {
      unawaited(notifier.markRead(notification.id));
      if (!mounted) return;
      await _openCalendarNotification(notification);
      return;
    }

    final route = notification.route;
    if (!mounted) return;
    if (route != null) {
      context.go(route);
    }
    unawaited(notifier.dismiss(notification.id));
  }

  Future<void> _acceptFollowRequest(AppNotification notification) async {
    final requestId = notification.requestId;
    if (requestId == null) return;

    setState(() => _busyFollowRequestId = requestId);
    try {
      await ref.read(profileFollowControllerProvider).acceptRequest(
            requestId,
            requesterId: notification.profileId,
          );
      await ref.read(notificationsProvider.notifier).dismiss(notification.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo aceptar la solicitud')),
      );
    } finally {
      if (mounted) setState(() => _busyFollowRequestId = null);
    }
  }

  Future<void> _rejectFollowRequest(AppNotification notification) async {
    final requestId = notification.requestId;
    if (requestId == null) return;

    setState(() => _busyFollowRequestId = requestId);
    try {
      await ref.read(profileFollowControllerProvider).rejectRequest(requestId);
      await ref.read(notificationsProvider.notifier).dismiss(notification.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo rechazar la solicitud')),
      );
    } finally {
      if (mounted) setState(() => _busyFollowRequestId = null);
    }
  }

  Future<void> _showTopicRejectedSheet(AppNotification notification) async {
    final topicLabel = (notification.topicTitle?.trim().isNotEmpty ?? false)
        ? notification.topicTitle!.trim()
        : null;
    final reason = (notification.rejectionReason?.trim().isNotEmpty ?? false)
        ? notification.rejectionReason!.trim()
        : (notification.subtitle.trim().isNotEmpty
            ? notification.subtitle.trim()
            : 'La Junta no ha publicado este tema.');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tema no publicado',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (topicLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  '«$topicLabel»',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Motivo de la Junta',
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      color: AppColors.burgundy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                reason,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      },
    );
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: forumsBeigeDecorationImage(context),
      ),
      child: SafeArea(
        bottom: false,
        child: notificationsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const NotificationsListSkeleton(),
          error: (_, _) => CofradeoErrorPanel(
            message: 'No se pudieron cargar las notificaciones.',
            subtitle: 'Comprueba tu conexión e inténtalo de nuevo.',
            onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (notifications) => RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationsProvider.notifier).silentRefresh(),
            child: _NotificationsList(
              notifications: notifications,
              busyFollowRequestId: _busyFollowRequestId,
              onTap: _onNotificationTap,
              onAcceptFollowRequest: _acceptFollowRequest,
              onRejectFollowRequest: _rejectFollowRequest,
              onDismiss: (n) =>
                  ref.read(notificationsProvider.notifier).dismiss(n.id),
              onMarkAllRead: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              onClearAll: _confirmClear,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsList extends StatefulWidget {
  const _NotificationsList({
    required this.notifications,
    required this.onTap,
    required this.onDismiss,
    required this.onMarkAllRead,
    required this.onClearAll,
    required this.onAcceptFollowRequest,
    required this.onRejectFollowRequest,
    this.busyFollowRequestId,
  });

  final List<AppNotification> notifications;
  final String? busyFollowRequestId;
  final Future<void> Function(AppNotification notification) onTap;
  final Future<void> Function(AppNotification notification) onDismiss;
  final Future<void> Function(AppNotification notification)
      onAcceptFollowRequest;
  final Future<void> Function(AppNotification notification)
      onRejectFollowRequest;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  @override
  State<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<_NotificationsList> {
  final Set<String> _dismissedIds = {};

  @override
  void didUpdateWidget(covariant _NotificationsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibleIds = widget.notifications.map((n) => n.id).toSet();
    _dismissedIds.removeWhere((id) => !visibleIds.contains(id));
  }

  List<AppNotification> get _visibleNotifications => widget.notifications
      .where((notification) => !_dismissedIds.contains(notification.id))
      .toList();

  Future<void> _handleDismiss(AppNotification notification) async {
    setState(() => _dismissedIds.add(notification.id));
    await widget.onDismiss(notification);
    if (!mounted) return;
    final stillVisible =
        widget.notifications.any((n) => n.id == notification.id);
    if (stillVisible) {
      setState(() => _dismissedIds.remove(notification.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _visibleNotifications;
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            NotificationsDesign.screenPadding,
            10,
            NotificationsDesign.screenPadding,
            12,
          ),
          sliver: SliverToBoxAdapter(
            child: NotificationsScreenHeader(
              unreadCount: unreadCount,
              totalCount: notifications.length,
              onMarkAllRead: widget.onMarkAllRead,
              onClearAll: widget.onClearAll,
            ),
          ),
        ),
        if (notifications.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: NotificationsDesign.screenPadding,
            ),
            sliver: const SliverToBoxAdapter(
              child: NotificationsEmptyState(),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              NotificationsDesign.screenPadding,
              0,
              NotificationsDesign.screenPadding,
              28,
            ),
            sliver: SliverList.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: NotificationsDesign.cardGap),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        NotificationsDesign.cardRadius,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.burgundy.withValues(alpha: 0.75),
                    ),
                  ),
                  onDismissed: (_) => _handleDismiss(notification),
                  child: NotificationCard(
                    notification: notification,
                    onTap: () => widget.onTap(notification),
                    onAcceptFollowRequest: () =>
                        widget.onAcceptFollowRequest(notification),
                    onRejectFollowRequest: () =>
                        widget.onRejectFollowRequest(notification),
                    followRequestBusy:
                        notification.requestId != null &&
                        notification.requestId == widget.busyFollowRequestId,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
