import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/cofradeo_bottom_nav.dart';
import '../calendar/calendar_provider.dart';
import '../notifications/notifications_provider.dart';

class CofradeoShell extends ConsumerWidget {
  const CofradeoShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index, WidgetRef ref) {
    if (index == 3) {
      Future.microtask(() async {
        await ref.read(notificationsProvider.notifier).silentRefresh();
        await ref.read(notificationsProvider.notifier).markAllRead();
      });
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationsRealtimeProvider);
    ref.watch(notificationsProvider);

    final showCalendarDot = ref.watch(calendarHasEventTodayProvider);
    final showNotificationsDot = ref.watch(hasUnreadNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: CofradeoBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(index, ref),
        showCalendarDot: showCalendarDot,
        showNotificationsDot: showNotificationsDot,
      ),
    );
  }
}
