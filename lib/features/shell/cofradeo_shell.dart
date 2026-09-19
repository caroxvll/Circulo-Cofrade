import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/cofradeo_bottom_nav.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/liturgical_countdown_provider.dart';
import '../auth/auth_provider.dart';
import '../forums/forums_provider.dart';
import '../forums/widgets/forums_shell_ad_bar.dart';
import '../forums/widgets/noticias_shell_ad_bar.dart';
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
    // No invalidar ads/countdown en cada tap: pelean con la transición.
    // Realtime + pull-to-refresh / vuelta de background cubren datos frescos.
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

    final path = GoRouterState.of(context).uri.path;
    final onForumsTab = navigationShell.currentIndex == 1;
    final showForumsAd = onForumsTab && path == '/foros';
    final showNoticiasAd = onForumsTab && path == '/foros/noticias';

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showForumsAd) const ForumsShellAdBar(),
          if (showNoticiasAd) const NoticiasShellAdBar(),
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
