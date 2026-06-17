import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/cofradeo_badge.dart';
import '../../core/widgets/screen_title_row.dart';
import '../../shared/models/forum.dart';
import '../../shared/models/user_role.dart';
import '../forums/forums_provider.dart';
import '../profile/profile_provider.dart';
import '../moderation/moderation_provider.dart';
import 'admin_provider.dart';
import 'data/admin_repository.dart';
import 'widgets/junta_pillars_tab.dart';

class JuntaScreen extends ConsumerWidget {
  const JuntaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = ref.watch(isStaffProvider);

    if (!isStaff) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/perfil'),
              ),
              const SizedBox(height: 24),
              Text(
                'Acceso restringido',
                style: AppTypography.displaySmall(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Solo la Junta de Gobierno puede acceder a este panel.',
                style: AppTypography.bodyMedium(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/perfil'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                ),
                child: const Text('Volver al perfil'),
              ),
            ],
          ),
        ),
      );
    }

    final isAdmin = ref.watch(isAdminProvider);

    return DefaultTabController(
      length: isAdmin ? 3 : 2,
      child: _JuntaDashboardBody(isAdmin: isAdmin),
    );
  }
}

class _JuntaDashboardBody extends ConsumerWidget {
  const _JuntaDashboardBody({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final topicsAsync = ref.watch(pendingTopicsProvider);
    final reportGroupsAsync = ref.watch(pendingReportGroupsProvider);
    final reportsAsync = ref.watch(pendingReportsProvider);
    final tabController = DefaultTabController.of(context);

    final topicCount = topicsAsync.asData?.value.length ?? 0;
    final reportGroupCount = reportGroupsAsync.asData?.value.length ?? 0;
    final totalReportCount = reportsAsync.asData?.value.length ?? 0;
    final isLoading =
        topicsAsync.isLoading ||
        reportGroupsAsync.isLoading ||
        reportsAsync.isLoading;
    final pendingTotal = topicCount + reportGroupCount;

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.burgundy,
                        onPressed: () => context.go('/perfil'),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScreenTitleRow(
                                title: 'Junta',
                                trailing: [
                                  if (profile != null &&
                                      profile.role.isStaff)
                                    CofradeoBadge(
                                      label: profile.role == UserRole.admin
                                          ? 'Admin'
                                          : 'Moderador',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Moderación de la comunidad',
                                style: AppTypography.bodyMedium(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _OverviewCard(
                    pendingTotal: pendingTotal,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.rate_review_outlined,
                          label: 'Temas',
                          count: isLoading ? null : topicCount,
                          onTap: () => tabController.animateTo(0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          icon: Icons.flag_outlined,
                          label: 'Reportes',
                          count: isLoading ? null : reportGroupCount,
                          subtitle: totalReportCount > reportGroupCount
                              ? '$totalReportCount en total'
                              : null,
                          onTap: () => tabController.animateTo(1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _JuntaTabBarDelegate(
              TabBar(
                labelStyle: AppTypography.titleLarge().copyWith(fontSize: 15),
                unselectedLabelStyle: AppTypography.bodyLarge(
                  color: AppColors.textMuted,
                ).copyWith(fontWeight: FontWeight.w500),
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.accentRed,
                indicatorWeight: 3,
                dividerColor: AppColors.border,
                tabs: [
                  Tab(text: 'Temas${topicCount > 0 ? ' ($topicCount)' : ''}'),
                  Tab(
                    text:
                        'Reportes${reportGroupCount > 0 ? ' ($reportGroupCount)' : ''}',
                  ),
                  if (isAdmin) const Tab(text: 'Pilares'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            const _PendingTopicsTab(),
            const _PendingReportsTab(),
            if (isAdmin) const JuntaPillarsTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.pendingTotal,
    required this.isLoading,
  });

  final int pendingTotal;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final allClear = !isLoading && pendingTotal == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.burgundy.withValues(alpha: 0.12),
            ),
            child: Icon(
              isLoading
                  ? Icons.hourglass_empty_outlined
                  : allClear
                      ? Icons.verified_outlined
                      : Icons.pending_actions_outlined,
              color: AppColors.burgundy,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading
                      ? 'Actualizando…'
                      : allClear
                          ? 'Todo al día'
                          : '$pendingTotal pendiente${pendingTotal == 1 ? '' : 's'}',
                  style: AppTypography.titleLarge().copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Cargando temas y reportes.'
                      : allClear
                          ? 'No hay nada esperando revisión.'
                          : 'Revisa la cola de abajo.',
                  style: AppTypography.bodyMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final int? count;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.burgundy,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (count == null)
                      const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        '$count',
                        style: AppTypography.displaySmall(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 22),
                      ),
                    Text(label, style: AppTypography.labelSmall()),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.goldDark,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JuntaTabBarDelegate extends SliverPersistentHeaderDelegate {
  _JuntaTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _JuntaTabBarDelegate oldDelegate) => false;
}

class _PendingTopicsTab extends ConsumerWidget {
  const _PendingTopicsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(pendingTopicsProvider);

    return topicsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyState(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar los temas.',
        onRetry: () => ref.invalidate(pendingTopicsProvider),
      ),
      data: (topics) {
        if (topics.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            message: 'Sin temas pendientes',
            subtitle: 'Los nuevos hilos aparecerán aquí.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingTopicsProvider);
            await ref.read(pendingTopicsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _PendingTopicCard(topic: topics[index]);
            },
          ),
        );
      },
    );
  }
}

class _PendingTopicCard extends ConsumerStatefulWidget {
  const _PendingTopicCard({required this.topic});

  final ForumTopic topic;

  @override
  ConsumerState<_PendingTopicCard> createState() => _PendingTopicCardState();
}

class _PendingTopicCardState extends ConsumerState<_PendingTopicCard> {
  var _busy = false;

  Future<void> _moderate(TopicStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setTopicStatus(
            topicId: widget.topic.id,
            status: status,
          );
      ref.invalidate(pendingTopicsProvider);
      ref.invalidate(forumTopicsProvider(widget.topic.forumId));
      final authorId = widget.topic.authorId;
      if (authorId != null) {
        ref.invalidate(userActivityProvider(authorId));
      }
      if (mounted) {
        final label =
            status == TopicStatus.published ? 'aprobado' : 'rechazado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tema $label')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el tema')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(
          '/foros/${topic.forumId}/tema/${topic.id}',
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CofradeoBadge(label: 'Pendiente'),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.goldDark,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                style: AppTypography.displaySmall(
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                '${topic.authorHandle} · ${topic.timeAgo}',
                style: AppTypography.labelSmall(),
              ),
              if (topic.excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  topic.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => _moderate(TopicStatus.rejected),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _moderate(TopicStatus.published),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: AppColors.textOnDark,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingReportsTab extends ConsumerWidget {
  const _PendingReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(pendingReportGroupsProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _EmptyState(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar los reportes.',
        onRetry: () {
          ref.invalidate(pendingReportsProvider);
          ref.invalidate(pendingReportGroupsProvider);
        },
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const _EmptyState(
            icon: Icons.shield_outlined,
            message: 'Sin reportes pendientes',
            subtitle:
                'Los reportes de usuarios aparecerán aquí. Los bloqueos son privados y no llegan a la Junta.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingReportsProvider);
            ref.invalidate(pendingReportGroupsProvider);
            await ref.read(pendingReportGroupsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: groups.length + 1,
            separatorBuilder: (_, index) =>
                index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _ReportsInfoBanner();
              }
              return _ReportGroupCard(group: groups[index - 1]);
            },
          ),
        );
      },
    );
  }
}

class _ReportsInfoBanner extends StatelessWidget {
  const _ReportsInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.burgundy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bloquear es personal: cada usuario oculta a quien quiera. '
              'Reportar avisa a la Junta (perfiles, temas y respuestas). '
              'Varios reportes sobre el mismo objetivo se agrupan.',
              style: AppTypography.bodyMedium().copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportGroupCard extends ConsumerStatefulWidget {
  const _ReportGroupCard({required this.group});

  final ModerationReportGroup group;

  @override
  ConsumerState<_ReportGroupCard> createState() => _ReportGroupCardState();
}

class _ReportGroupCardState extends ConsumerState<_ReportGroupCard> {
  var _busy = false;
  var _expanded = false;

  Future<void> _suspendAccount() async {
    final group = widget.group;
    final authorId = group.authorProfileId;
    if (authorId == null) return;

    final authorLabel = group.targetType == 'profile'
        ? group.targetLabel
        : 'al autor de «${group.targetLabel}»';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Suspender $authorLabel?'),
        content: Text(
          'La cuenta no podrá publicar ni responder en foros. '
          'Motivo: ${group.reasonsSummary}.\n\n'
          'Los reportes pendientes se marcarán como revisados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
            ),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.suspendProfile(
        profileId: authorId,
        reason: group.reasonsSummary,
      );
      await repo.resolveReportsForTarget(
        targetType: group.targetType,
        targetId: group.targetId,
      );
      ref.invalidate(pendingReportsProvider);
      ref.invalidate(pendingReportGroupsProvider);
      invalidateAuthorVisibility(ref, profileId: authorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta suspendida')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo suspender. ¿Ejecutaste profile_suspension.sql?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reactivateAccount() async {
    final group = widget.group;
    final authorId = group.authorProfileId;
    if (authorId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).unsuspendProfile(authorId);
      invalidateAuthorVisibility(ref, profileId: authorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta reactivada')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reactivar la cuenta')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveAll() async {
    setState(() => _busy = true);
    try {
      final group = widget.group;
      await ref.read(adminRepositoryProvider).resolveReportsForTarget(
            targetType: group.targetType,
            targetId: group.targetId,
          );
      ref.invalidate(pendingReportsProvider);
      ref.invalidate(pendingReportGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              group.count == 1
                  ? 'Reporte revisado'
                  : '${group.count} reportes revisados',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron actualizar los reportes')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openTarget(BuildContext context) {
    final group = widget.group;
    switch (group.targetType) {
      case 'profile':
        context.push('/perfil/usuario/${group.targetId}');
      case 'topic':
      case 'reply':
        final forumId = group.targetForumId;
        final topicId = group.targetTopicId;
        if (forumId != null && topicId != null) {
          context.push('/foros/$forumId/tema/$topicId');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final authorId = group.authorProfileId;
    final authorProfile = authorId != null
        ? ref.watch(userProfileProvider(authorId)).asData?.value
        : null;
    final isSuspended = authorProfile?.isSuspended ?? false;
    final canSuspend =
        authorProfile != null && !authorProfile.isStaff;
    final targetTypeLabel = switch (group.targetType) {
      'profile' => 'Perfil',
      'topic' => 'Tema',
      'reply' => 'Respuesta',
      _ => group.targetType,
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.burgundy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.targetLabel,
                        style: AppTypography.titleLarge().copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetTypeLabel,
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.count == 1
                            ? '${group.reasonsSummary} · ${group.latestTimeAgo}'
                            : '${group.count} reportes · ${group.reasonsSummary} · ${group.latestTimeAgo}',
                        style: AppTypography.labelSmall(),
                      ),
                    ],
                  ),
                ),
                if (group.count > 1) CofradeoBadge(label: '${group.count}'),
                if (isSuspended)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: CofradeoBadge(label: 'Suspendida'),
                  ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              for (final report in group.reports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '· ${report.reason}'
                    '${report.reporterHandle != null ? ' · ${report.reporterHandle}' : ''}'
                    '${report.details.isNotEmpty ? '\n  ${report.details}' : ''}',
                    style: AppTypography.bodyMedium().copyWith(fontSize: 13),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (group.count > 1)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Ocultar detalle' : 'Ver detalle',
                      style: AppTypography.labelSmall(color: AppColors.burgundy),
                    ),
                  ),
                if (group.targetType == 'profile')
                  TextButton(
                    onPressed: () => _openTarget(context),
                    child: Text(
                      'Ver perfil',
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (group.targetType == 'topic' || group.targetType == 'reply')
                  TextButton(
                    onPressed: () => _openTarget(context),
                    child: Text(
                      'Ver hilo',
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (authorId != null)
                  TextButton(
                    onPressed: () =>
                        context.push('/perfil/usuario/$authorId'),
                    child: Text(
                      'Ver autor',
                      style: AppTypography.labelSmall(
                        color: AppColors.burgundy,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (canSuspend && !isSuspended)
                  OutlinedButton(
                    onPressed: _busy ? null : _suspendAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.burgundy,
                      side: const BorderSide(color: AppColors.burgundy),
                    ),
                    child: const Text('Suspender'),
                  ),
                if (canSuspend && isSuspended)
                  OutlinedButton(
                    onPressed: _busy ? null : _reactivateAccount,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.burgundy,
                      side: const BorderSide(color: AppColors.burgundy),
                    ),
                    child: const Text('Reactivar'),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _resolveAll,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.textOnDark,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnDark,
                          ),
                        )
                      : Text(group.count == 1 ? 'Revisado' : 'Revisar todos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, style: AppTypography.titleLarge()),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
