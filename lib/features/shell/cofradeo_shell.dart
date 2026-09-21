import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/cofradeo_bottom_nav.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/liturgical_countdown_provider.dart';
import '../calendar/widgets/calendar_shell_ad_bar.dart';
import '../auth/auth_provider.dart';
import '../forums/forums_provider.dart';
import '../forums/widgets/forums_shell_ad_bar.dart';
import '../notifications/notifications_provider.dart';
import '../permissions/permissions_provider.dart';

class CofradeoShell extends ConsumerWidget {
  const CofradeoShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index, WidgetRef ref) {
    if (index == 4 && !ref.read(isAuthenticatedProvider)) {
      context.go('/login?redirect=${Uri.encodeComponent('/perfil')}');
      return;
    }
    // El re-sorteo de banners lo hacen CalendarShellAdBar / ForumsShellAdBar
    // al mostrarse (keepAlive + skipLoadingOnReload), sin pelear con la transición.
    if (index == 3) {
      Future.microtask(
        () => ref.read(notificationsProvider.notifier).silentRefresh(),
      );
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationsRealtimeProvider);
    ref.watch(permissionsRealtimeProvider);
    ref.watch(calendarRealtimeProvider);
    ref.watch(liturgicalCountdownRealtimeProvider);
    ref.watch(forumPillarsRealtimeProvider);
    ref.watch(notificationsProvider);

    final showCalendarDot = ref.watch(calendarHasEventTodayProvider);
    final showNotificationsDot = ref.watch(hasUnreadNotificationsProvider);

    final showForumsAd = navigationShell.currentIndex == 1 &&
        GoRouterState.of(context).uri.path == '/foros';
    final showCalendarAd = navigationShell.currentIndex == 0 &&
        GoRouterState.of(context).uri.path == '/calendario';

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCalendarAd) const CalendarShellAdBar(),
          if (showForumsAd) const ForumsShellAdBar(),
          CofradeoBottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => _onTap(context, index, ref),
            showCalendarDot: showCalendarDot,
            showNotificationsDot: showNotificationsDot,
          ),
        ],
      ),
    );
  }
}
