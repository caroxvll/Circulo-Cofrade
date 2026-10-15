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
import '../forums/mis_hermandades_provider.dart';
import '../forums/utils/noticias_forum.dart';
import '../forums/widgets/forums_shell_ad_bar.dart';
import '../forums/widgets/noticias_shell_ad_bar.dart';
import '../notifications/notifications_provider.dart';
import '../permissions/permissions_provider.dart';
import '../quiz/quiz_provider.dart';
import '../semana_santa/semana_santa_provider.dart';

/// Buscar es la rama 5 del shell (sin ítem en bottom nav).
const searchShellBranchIndex = 5;

/// Último tab principal (0–4) para volver desde Buscar / marcar el nav.
class ShellMainTabMemory {
  static int lastIndex = 0;
}

class CofradeoShell extends ConsumerStatefulWidget {
  const CofradeoShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<CofradeoShell> createState() => _CofradeoShellState();
}

class _CofradeoShellState extends ConsumerState<CofradeoShell> {
  void _rememberMainTab(int index) {
    if (index < searchShellBranchIndex) {
      ShellMainTabMemory.lastIndex = index;
    }
  }

  void _onTap(BuildContext context, int index) {
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
    // Prefetch al ir a Noticias.
    if (index == 1) {
      Future.microtask(() {
        ref.read(forumTopicsProvider(noticiasForumId).future);
      });
    }
    // Prefetch al ir a Foros: FAB, gate SS, hermandades y feed ya calientes.
    if (index == 2) {
      Future.microtask(() {
        ref.read(quizLiveVisibleProvider.future);
        ref.read(ssLiveGateProvider.future);
        ref.read(forumTopicsProvider('hermandades').future);
        ref.read(followedHermandadBoardsProvider.future);
        ref.read(followedHermandadFeedProvider.future);
        ref.read(ssLiveRawFeedProvider.future);
      });
    }
    _rememberMainTab(index);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationsRealtimeProvider);
    ref.watch(permissionsRealtimeProvider);
    ref.watch(calendarRealtimeProvider);
    ref.watch(liturgicalCountdownRealtimeProvider);
    ref.watch(forumPillarsRealtimeProvider);
    ref.watch(notificationsProvider);

    final showCalendarDot = ref.watch(calendarHasEventTodayProvider);
    final showNotificationsDot = ref.watch(hasUnreadNotificationsProvider);

    final path = GoRouterState.of(context).uri.path;
    final branchIndex = widget.navigationShell.currentIndex;
    _rememberMainTab(branchIndex);

    final isSearch = branchIndex == searchShellBranchIndex;
    final navIndex = isSearch ? ShellMainTabMemory.lastIndex : branchIndex;

    final showForumsAd = branchIndex == 2 && path == '/foros';
    final showNoticiasAd = branchIndex == 1 &&
        (path == '/noticias' || path == '/foros/$noticiasForumId');
    final showCalendarAd = branchIndex == 0 && path == '/calendario';

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCalendarAd) const CalendarShellAdBar(),
          if (showForumsAd) const ForumsShellAdBar(),
          if (showNoticiasAd) const NoticiasShellAdBar(),
          CofradeoBottomNav(
            currentIndex: navIndex,
            onTap: (index) => _onTap(context, index),
            showCalendarDot: showCalendarDot,
            showNotificationsDot: showNotificationsDot,
          ),
        ],
      ),
    );
  }
}
