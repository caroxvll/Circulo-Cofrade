import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../profile/profile_provider.dart';
import '../admin_provider.dart';
import '../junta_modules.dart';
import '../junta_ui.dart';
import 'admin_ads_tab.dart';
import 'junta_close_requests_tab.dart';
import 'junta_countdown_tab.dart';
import 'junta_hermandades_tab.dart';
import 'junta_moderation_panels.dart';
import 'junta_moderators_tab.dart';
import 'junta_pending_events_tab.dart';
import 'junta_pillars_tab.dart';
import 'junta_quiz_tab.dart';
import 'junta_rejected_topics_panel.dart';
import '../../quiz/quiz_provider.dart';
import '../../permissions/permissions_provider.dart';

const _railBreakpoint = 840.0;

class JuntaShell extends ConsumerWidget {
  const JuntaShell({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= _railBreakpoint;
    final selected = ref.watch(juntaSelectedModuleProvider);
    final counts = ref.watch(_juntaCountsProvider);
    final canCreateQuiz =
        ref.watch(canCreateQuizQuestionsAsyncProvider).asData?.value ??
            isAdmin;

    if (!visibleJuntaModules(
      isAdmin: isAdmin,
      canCreateQuiz: canCreateQuiz,
    ).contains(selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(juntaSelectedModuleProvider.notifier).select(
            JuntaModule.overview,
          );
      });
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JuntaHeader(
          isAdmin: isAdmin,
          selected: selected,
          showMenu: !useRail,
        ),
        Expanded(child: _JuntaModuleBody(module: selected)),
      ],
    );

    if (useRail) {
      return SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _JuntaNavigationRail(
              isAdmin: isAdmin,
              canCreateQuiz: canCreateQuiz,
              selected: selected,
              counts: counts,
              onSelect: (module) => _selectModule(context, ref, module),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: _JuntaDrawer(
          isAdmin: isAdmin,
          canCreateQuiz: canCreateQuiz,
          selected: selected,
          counts: counts,
          onSelect: (module) => _selectModule(context, ref, module),
        ),
        body: body,
      ),
    );
  }

  void _selectModule(
    BuildContext context,
    WidgetRef ref,
    JuntaModule module,
  ) {
    ref.read(juntaSelectedModuleProvider.notifier).select(module);
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }
}

class _JuntaCounts {
  const _JuntaCounts({
    required this.topics,
    required this.reports,
    required this.events,
    required this.closeRequests,
    required this.isLoading,
  });

  final int topics;
  final int reports;
  final int events;
  final int closeRequests;
  final bool isLoading;

  int badgeFor(JuntaModule module) => switch (module) {
    JuntaModule.topics => topics,
    JuntaModule.reports => reports,
    JuntaModule.events => events,
    JuntaModule.closeRequests => closeRequests,
    _ => 0,
  };

  int get moderationPending => topics + reports + closeRequests + events;
}

final _juntaCountsProvider = Provider<_JuntaCounts>((ref) {
  final topicsAsync = ref.watch(pendingTopicsProvider);
  final reportGroupsAsync = ref.watch(pendingReportGroupsProvider);
  final eventsAsync = ref.watch(pendingCalendarEventsProvider);
  final closeAsync = ref.watch(closeRequestedTopicsProvider);

  final isLoading = topicsAsync.isLoading ||
      reportGroupsAsync.isLoading ||
      eventsAsync.isLoading ||
      closeAsync.isLoading;

  return _JuntaCounts(
    topics: topicsAsync.asData?.value.length ?? 0,
    reports: reportGroupsAsync.asData?.value.length ?? 0,
    events: eventsAsync.asData?.value.length ?? 0,
    closeRequests: closeAsync.asData?.value.length ?? 0,
    isLoading: isLoading,
  );
});

class _JuntaHeader extends ConsumerWidget {
  const _JuntaHeader({
    required this.isAdmin,
    required this.selected,
    required this.showMenu,
  });

  final bool isAdmin;
  final JuntaModule selected;
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isOverview = selected == JuntaModule.overview;
    final title = isOverview ? 'JUNTA' : selected.label;
    final titleStyle =
        isOverview ? JuntaUi.shellTitle() : JuntaUi.moduleTitle();

    return Material(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showMenu)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, size: 22),
                  color: AppColors.burgundy,
                  tooltip: 'Módulos',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              color: AppColors.burgundy,
              tooltip: 'Volver al perfil',
              onPressed: () => context.go('/perfil'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: titleStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile != null && profile.isAdmin)
                          const CofradeoBadge(label: 'Admin')
                        else if (profile != null &&
                            ref.watch(isJuntaMemberProvider))
                          const CofradeoBadge(label: 'Moderador'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOverview
                          ? 'Moderación de la comunidad'
                          : 'Junta · ${selected.label}',
                      style: JuntaUi.caption(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuntaDrawer extends StatelessWidget {
  const _JuntaDrawer({
    required this.isAdmin,
    required this.canCreateQuiz,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final bool isAdmin;
  final bool canCreateQuiz;
  final JuntaModule selected;
  final _JuntaCounts counts;
  final ValueChanged<JuntaModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: _JuntaNavList(
          isAdmin: isAdmin,
          canCreateQuiz: canCreateQuiz,
          selected: selected,
          counts: counts,
          onSelect: onSelect,
          showHeader: true,
        ),
      ),
    );
  }
}

class _JuntaNavigationRail extends StatelessWidget {
  const _JuntaNavigationRail({
    required this.isAdmin,
    required this.canCreateQuiz,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  final bool isAdmin;
  final bool canCreateQuiz;
  final JuntaModule selected;
  final _JuntaCounts counts;
  final ValueChanged<JuntaModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JUNTA', style: JuntaUi.shellTitle()),
                  const SizedBox(height: 2),
                  Text('Panel de moderación', style: JuntaUi.caption()),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _JuntaNavList(
                isAdmin: isAdmin,
                canCreateQuiz: canCreateQuiz,
                selected: selected,
                counts: counts,
                onSelect: onSelect,
                showHeader: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuntaNavList extends StatelessWidget {
  const _JuntaNavList({
    required this.isAdmin,
    required this.canCreateQuiz,
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.showHeader,
  });

  final bool isAdmin;
  final bool canCreateQuiz;
  final JuntaModule selected;
  final _JuntaCounts counts;
  final ValueChanged<JuntaModule> onSelect;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final sections = [
      JuntaNavSection.moderation,
      if (isAdmin) JuntaNavSection.community,
      if (isAdmin || canCreateQuiz) JuntaNavSection.platform,
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(showHeader ? 8 : 4, showHeader ? 8 : 12, 8, 24),
      children: [
        if (showHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JUNTA', style: JuntaUi.shellTitle()),
                const SizedBox(height: 2),
                Text('Panel de moderación', style: JuntaUi.caption()),
              ],
            ),
          ),
        ],
        _JuntaNavTile(
          module: JuntaModule.overview,
          selected: selected == JuntaModule.overview,
          badge: counts.moderationPending,
          onTap: () => onSelect(JuntaModule.overview),
        ),
        for (final section in sections) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              section.title.toUpperCase(),
              style: JuntaUi.sectionHeader(),
            ),
          ),
          for (final module in modulesInSection(
            section,
            isAdmin: isAdmin,
            canCreateQuiz: canCreateQuiz,
          ))
            _JuntaNavTile(
              module: module,
              selected: selected == module,
              badge: counts.badgeFor(module),
              onTap: () => onSelect(module),
            ),
        ],
      ],
    );
  }
}

class _JuntaNavTile extends StatelessWidget {
  const _JuntaNavTile({
    required this.module,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final JuntaModule module;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.burgundy : AppColors.textPrimary;
    final bg = selected
        ? AppColors.burgundy.withValues(alpha: 0.08)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(module.icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    module.shortLabel ?? module.label,
                    style: JuntaUi.navLabel(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: JuntaUi.caption(color: AppColors.textOnDark)
                          .copyWith(fontWeight: FontWeight.w700),
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

class _JuntaModuleBody extends StatelessWidget {
  const _JuntaModuleBody({required this.module});

  final JuntaModule module;

  @override
  Widget build(BuildContext context) {
    return switch (module) {
      JuntaModule.overview => const _JuntaOverviewPanel(),
      JuntaModule.topics => const JuntaPendingTopicsPanel(),
      JuntaModule.rejectedTopics => const JuntaRejectedTopicsPanel(),
      JuntaModule.reports => const JuntaPendingReportsPanel(),
      JuntaModule.events => const JuntaPendingEventsTab(),
      JuntaModule.closeRequests => const JuntaCloseRequestsTab(),
      JuntaModule.moderators => const JuntaModeratorsTab(),
      JuntaModule.hermandades => const JuntaHermandadesTab(),
      JuntaModule.forums => const JuntaPillarsTab(),
      JuntaModule.season => const JuntaCountdownTab(),
      JuntaModule.ads => const AdminAdsTab(),
      JuntaModule.quiz => const JuntaQuizTab(),
    };
  }
}

class _JuntaOverviewPanel extends ConsumerWidget {
  const _JuntaOverviewPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final canCreateQuiz =
        ref.watch(canCreateQuizQuestionsAsyncProvider).asData?.value ?? false;
    final counts = ref.watch(_juntaCountsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingTopicsProvider);
        ref.invalidate(pendingReportGroupsProvider);
        ref.invalidate(pendingCalendarEventsProvider);
        ref.invalidate(closeRequestedTopicsProvider);
      },
      child: ListView(
        padding: JuntaUi.listPadding,
        children: [
          _OverviewStatusCard(counts: counts),
          const SizedBox(height: 20),
          _OverviewSection(
            title: JuntaNavSection.moderation.title,
            modules: modulesInSection(
              JuntaNavSection.moderation,
              isAdmin: isAdmin,
              canCreateQuiz: canCreateQuiz,
            ),
            counts: counts,
            onSelect: (module) => ref
                .read(juntaSelectedModuleProvider.notifier)
                .select(module),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 20),
            _OverviewSection(
              title: JuntaNavSection.community.title,
              modules: modulesInSection(
                JuntaNavSection.community,
                isAdmin: isAdmin,
                canCreateQuiz: canCreateQuiz,
              ),
              counts: counts,
              onSelect: (module) => ref
                  .read(juntaSelectedModuleProvider.notifier)
                  .select(module),
            ),
          ],
          if (isAdmin || canCreateQuiz) ...[
            const SizedBox(height: 20),
            _OverviewSection(
              title: JuntaNavSection.platform.title,
              modules: modulesInSection(
                JuntaNavSection.platform,
                isAdmin: isAdmin,
                canCreateQuiz: canCreateQuiz,
              ),
              counts: counts,
              onSelect: (module) => ref
                  .read(juntaSelectedModuleProvider.notifier)
                  .select(module),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewStatusCard extends StatelessWidget {
  const _OverviewStatusCard({required this.counts});

  final _JuntaCounts counts;

  @override
  Widget build(BuildContext context) {
    final allClear = !counts.isLoading && counts.moderationPending == 0;

    return Container(
      width: double.infinity,
      padding: JuntaUi.cardPadding,
      decoration: JuntaUi.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: JuntaUi.iconCircleSize,
            height: JuntaUi.iconCircleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.burgundy.withValues(alpha: 0.12),
            ),
            child: Icon(
              counts.isLoading
                  ? Icons.hourglass_empty_outlined
                  : allClear
                  ? Icons.verified_outlined
                  : Icons.pending_actions_outlined,
              color: AppColors.burgundy,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  counts.isLoading
                      ? 'Actualizando…'
                      : allClear
                      ? 'Todo al día'
                      : '${counts.moderationPending} pendiente${counts.moderationPending == 1 ? '' : 's'}',
                  style: JuntaUi.cardTitle(),
                ),
                const SizedBox(height: 2),
                Text(
                  counts.isLoading
                      ? 'Cargando colas de moderación.'
                      : allClear
                      ? 'No hay nada esperando revisión.'
                      : 'Toca un módulo para revisarlo.',
                  style: JuntaUi.body(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({
    required this.title,
    required this.modules,
    required this.counts,
    required this.onSelect,
  });

  final String title;
  final List<JuntaModule> modules;
  final _JuntaCounts counts;
  final ValueChanged<JuntaModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: JuntaUi.sectionHeader()),
        const SizedBox(height: 6),
        for (var i = 0; i < modules.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OverviewModuleTile(
            module: modules[i],
            badge: counts.badgeFor(modules[i]),
            onTap: () => onSelect(modules[i]),
          ),
        ],
      ],
    );
  }
}

class _OverviewModuleTile extends StatelessWidget {
  const _OverviewModuleTile({
    required this.module,
    required this.badge,
    required this.onTap,
  });

  final JuntaModule module;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: JuntaUi.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: JuntaUi.iconCircleSize,
                height: JuntaUi.iconCircleSize,
                decoration: const BoxDecoration(
                  color: AppColors.burgundy,
                  shape: BoxShape.circle,
                ),
                child: Icon(module.icon, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(module.label, style: JuntaUi.cardTitle()),
              ),
              if (badge > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: JuntaUi.caption(color: AppColors.textOnDark)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.goldDark,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
