import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../shared/models/forum.dart';
import '../../forums/forums_provider.dart';
import '../../forums/widgets/forum_post_image.dart';
import '../../moderation/moderation_provider.dart';
import '../../permissions/permissions_provider.dart';
import '../../profile/profile_provider.dart';
import '../admin_provider.dart';
import '../data/admin_repository.dart';
import '../junta_ui.dart';

class JuntaPendingTopicsPanel extends ConsumerWidget {
  const JuntaPendingTopicsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pendingTopicsRealtimeProvider);
    final topicsAsync = ref.watch(pendingTopicsProvider);

    return topicsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => JuntaEmptyPanel(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar los temas.',
        onRetry: () => ref.invalidate(pendingTopicsProvider),
      ),
      data: (topics) {
        if (topics.isEmpty) {
          return const JuntaEmptyPanel(
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
            padding: JuntaUi.listPadding,
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

class JuntaPendingReportsPanel extends ConsumerWidget {
  const JuntaPendingReportsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(pendingReportGroupsProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => JuntaEmptyPanel(
        icon: Icons.error_outline,
        message: 'No se pudieron cargar los reportes.',
        onRetry: () {
          ref.invalidate(pendingReportsProvider);
          ref.invalidate(pendingReportGroupsProvider);
        },
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const JuntaEmptyPanel(
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
            padding: JuntaUi.listPadding,
            itemCount: groups.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 12)
                : const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const JuntaInfoBanner(
                  text:
                      'Bloquear es personal: cada usuario oculta a quien quiera. '
                      'Reportar avisa a la Junta (perfiles, temas y respuestas). '
                      'Varios reportes sobre el mismo objetivo se agrupan.',
                );
              }
              return _ReportGroupCard(group: groups[index - 1]);
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
    String? rejectionReason;
    if (status == TopicStatus.rejected) {
      rejectionReason = await _askRejectionReason();
      if (rejectionReason == null || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setTopicStatus(
            topicId: widget.topic.id,
            status: status,
            rejectionReason: rejectionReason,
          );
      ref.invalidate(pendingTopicsProvider);
      ref.invalidate(rejectedTopicsProvider);
      ref.invalidate(forumTopicsProvider(widget.topic.forumId));
      final authorId = widget.topic.authorId;
      if (authorId != null) {
        ref.invalidate(userActivityProvider(authorId));
      }
      if (mounted) {
        final label = status == TopicStatus.published
            ? 'aprobado'
            : 'rechazado';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tema $label')));
      }
    } on TopicRejectionReasonRequiredException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica un motivo de rechazo')),
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

  Future<String?> _askRejectionReason() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (ctx) => _RejectTopicReasonSheet(topicTitle: widget.topic.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final coverUrl = _pendingTopicCoverUrl(topic);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        onTap: () => context.push('/foros/${topic.forumId}/tema/${topic.id}'),
        child: Container(
          padding: JuntaUi.cardPadding,
          decoration: JuntaUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CofradeoBadge(label: 'Pendiente'),
                  if (coverUrl != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'Con cartel',
                        style: JuntaUi.caption().copyWith(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.goldDark,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(topic.title, style: JuntaUi.cardTitle()),
              const SizedBox(height: 4),
              Text(
                '${topic.authorHandle} · ${topic.timeAgo}',
                style: JuntaUi.caption(),
              ),
              if (topic.excerpt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  topic.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: JuntaUi.body(),
                ),
              ],
              if (coverUrl != null) ...[
                const SizedBox(height: 10),
                ForumPostImage(
                  imageUrl: coverUrl,
                  shareText: topic.title,
                  maxPreviewHeight: 240,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _moderate(TopicStatus.rejected),
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

String? _pendingTopicCoverUrl(ForumTopic topic) {
  final url = topic.coverImageUrl?.trim();
  if (url == null || url.isEmpty || url.startsWith('assets/')) return null;
  return url;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cuenta suspendida')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cuenta reactivada')));
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
      await ref
          .read(adminRepositoryProvider)
          .resolveReportsForTarget(
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
          const SnackBar(
            content: Text('No se pudieron actualizar los reportes'),
          ),
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
    final isAdmin = ref.watch(isAdminProvider);
    final canSuspend =
        authorProfile != null && !authorProfile.isAdmin && isAdmin;
    final targetTypeLabel = switch (group.targetType) {
      'profile' => 'Perfil',
      'topic' => 'Tema',
      'reply' => 'Respuesta',
      _ => group.targetType,
    };

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
      child: Container(
        padding: JuntaUi.cardPadding,
        decoration: JuntaUi.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: JuntaUi.iconCircleSize,
                  height: JuntaUi.iconCircleSize,
                  decoration: const BoxDecoration(
                    color: AppColors.burgundy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.gold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.targetLabel,
                        style: JuntaUi.cardTitle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(targetTypeLabel, style: JuntaUi.caption()),
                      const SizedBox(height: 2),
                      Text(
                        group.count == 1
                            ? '${group.reasonsSummary} · ${group.latestTimeAgo}'
                            : '${group.count} reportes · ${group.reasonsSummary} · ${group.latestTimeAgo}',
                        style: JuntaUi.caption(),
                      ),
                      if (group.count > 1 || isSuspended) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (group.count > 1)
                              CofradeoBadge(label: '${group.count}'),
                            if (isSuspended)
                              const CofradeoBadge(label: 'Suspendida'),
                          ],
                        ),
                      ],
                    ],
                  ),
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
                    style: JuntaUi.body(),
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
                      style: JuntaUi.caption(color: AppColors.burgundy),
                    ),
                  ),
                if (group.targetType == 'profile')
                  TextButton(
                    onPressed: () => _openTarget(context),
                    child: Text(
                      'Ver perfil',
                      style: JuntaUi.caption(color: AppColors.burgundy)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (group.targetType == 'topic' || group.targetType == 'reply')
                  TextButton(
                    onPressed: () => _openTarget(context),
                    child: Text(
                      'Ver hilo',
                      style: JuntaUi.caption(color: AppColors.burgundy)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (authorId != null)
                  TextButton(
                    onPressed: () => context.push('/perfil/usuario/$authorId'),
                    child: Text(
                      'Ver autor',
                      style: JuntaUi.caption(color: AppColors.burgundy)
                          .copyWith(fontWeight: FontWeight.w600),
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

const _rejectionReasonPresets = <String>[
  'Ya existe un tema igual o muy similar',
  'Fuera de tema para este foro',
  'Contenido inadecuado o no permitido',
  'Falta información o es demasiado genérico',
];

class _RejectTopicReasonSheet extends StatefulWidget {
  const _RejectTopicReasonSheet({required this.topicTitle});

  final String topicTitle;

  @override
  State<_RejectTopicReasonSheet> createState() =>
      _RejectTopicReasonSheetState();
}

class _RejectTopicReasonSheetState extends State<_RejectTopicReasonSheet> {
  final _controller = TextEditingController();
  String? _selectedPreset;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _resolvedReason {
    final custom = _controller.text.trim();
    if (custom.length >= 3) return custom;
    final preset = _selectedPreset?.trim();
    if (preset != null && preset.length >= 3) return preset;
    return null;
  }

  void _submit() {
    final reason = _resolvedReason;
    if (reason == null) return;
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final canSubmit = _resolvedReason != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Motivo del rechazo', style: JuntaUi.moduleTitle()),
          const SizedBox(height: 6),
          Text(
            '«${widget.topicTitle}»',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: JuntaUi.body(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _rejectionReasonPresets)
                ChoiceChip(
                  label: Text(preset, style: JuntaUi.caption()),
                  selected: _selectedPreset == preset,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPreset = selected ? preset : null;
                      if (selected) {
                        _controller.clear();
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLength: 280,
            maxLines: 3,
            minLines: 2,
            onChanged: (_) => setState(() {
              if (_controller.text.trim().isNotEmpty) {
                _selectedPreset = null;
              }
            }),
            decoration: JuntaUi.inputDecoration(
              labelText: 'Otro motivo',
              hintText: 'Explica al autor por qué no se publica',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.textOnDark,
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
