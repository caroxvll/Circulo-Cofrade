import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_badge.dart';
import '../../../shared/models/forum.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

class JuntaRejectedTopicsPanel extends ConsumerWidget {
  const JuntaRejectedTopicsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(rejectedTopicsProvider);

    return pageAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => JuntaEmptyPanel(
        icon: Icons.error_outline,
        message: 'No se pudo cargar el historial.',
        onRetry: () => ref.invalidate(rejectedTopicsProvider),
      ),
      data: (page) {
        if (page.topics.isEmpty) {
          return const JuntaEmptyPanel(
            icon: Icons.history_outlined,
            message: 'Sin rechazos todavía',
            subtitle: 'Cuando la Junta rechace un tema, aparecerá aquí.',
          );
        }

        final itemCount = page.topics.length + (page.hasMore ? 1 : 0);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(rejectedTopicsProvider);
            await ref.read(rejectedTopicsProvider.future);
          },
          child: ListView.separated(
            padding: JuntaUi.listPadding,
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= page.topics.length) {
                return _LoadMoreRejectedButton(
                  loading: page.isLoadingMore,
                  onPressed: () =>
                      ref.read(rejectedTopicsProvider.notifier).loadMore(),
                );
              }
              return _RejectedTopicCard(topic: page.topics[index]);
            },
          ),
        );
      },
    );
  }
}

class _LoadMoreRejectedButton extends StatelessWidget {
  const _LoadMoreRejectedButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(
                onPressed: onPressed,
                child: const Text('Cargar más'),
              ),
      ),
    );
  }
}

class _RejectedTopicCard extends ConsumerStatefulWidget {
  const _RejectedTopicCard({required this.topic});

  final ForumTopic topic;

  @override
  ConsumerState<_RejectedTopicCard> createState() => _RejectedTopicCardState();
}

class _RejectedTopicCardState extends ConsumerState<_RejectedTopicCard> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final topic = widget.topic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar «${topic.title}»?'),
        content: const Text(
          'Se borrará el tema rechazado y sus respuestas de la base de datos. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(rejectedTopicsProvider.notifier).deleteTopic(topic.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${topic.title}» eliminado')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el tema.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final reason = topic.rejectionReason?.trim();
    final hasReason = reason != null && reason.isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        onTap: _deleting
            ? null
            : () => context.push('/foros/${topic.forumId}/tema/${topic.id}'),
        child: Container(
          padding: JuntaUi.cardPadding,
          decoration: JuntaUi.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CofradeoBadge(label: 'Rechazado'),
                  const Spacer(),
                  Text(topic.timeAgo, style: JuntaUi.caption()),
                  IconButton(
                    onPressed: _deleting ? null : _confirmDelete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar de la base de datos',
                    color: AppColors.accentRed,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
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
                topic.authorHandle,
                style: JuntaUi.caption(),
              ),
              const SizedBox(height: 10),
              Text(
                'Motivo',
                style: JuntaUi.sectionTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                hasReason ? reason : 'Sin motivo registrado',
                style: JuntaUi.body(
                  color: hasReason
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
