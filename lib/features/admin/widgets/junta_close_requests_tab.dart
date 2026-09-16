import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/forum.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

class JuntaCloseRequestsTab extends ConsumerWidget {
  const JuntaCloseRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(closeRequestedTopicsProvider);

    return topicsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: JuntaUi.body(color: AppColors.accentRed)),
      ),
      data: (topics) {
        if (topics.isEmpty) {
          return JuntaEmptyPanel(
            icon: Icons.lock_open_outlined,
            message: 'No hay solicitudes de cierre pendientes.',
            subtitle: 'Cuando un autor pida cerrar un hilo, aparecerá aquí.',
          );
        }

        return ListView.separated(
          padding: JuntaUi.listPadding,
          itemCount: topics.length,
          separatorBuilder: (_, _) => const SizedBox(height: JuntaUi.itemGap),
          itemBuilder: (context, index) {
            return _CloseRequestCard(topic: topics[index]);
          },
        );
      },
    );
  }
}

class _CloseRequestCard extends ConsumerStatefulWidget {
  const _CloseRequestCard({required this.topic});

  final ForumTopic topic;

  @override
  ConsumerState<_CloseRequestCard> createState() => _CloseRequestCardState();
}

class _CloseRequestCardState extends ConsumerState<_CloseRequestCard> {
  var _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .approveTopicClose(widget.topic.id);
      ref.invalidate(closeRequestedTopicsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tema cerrado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cerrar el tema')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .rejectTopicCloseRequest(widget.topic.id);
      ref.invalidate(closeRequestedTopicsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de cierre rechazada')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo rechazar la solicitud')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: JuntaUi.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: JuntaUi.cardTitle()),
            const SizedBox(height: 4),
            Text(
              'Por ${topic.authorHandle} · ${topic.timeAgo}',
              style: JuntaUi.caption(),
            ),
            if (topic.excerpt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(topic.excerpt, style: JuntaUi.body(), maxLines: 2),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _approve,
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
                        : const Text('Cerrar tema'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    context.push('/foros/${topic.forumId}/tema/${topic.id}'),
                child: const Text('Ver hilo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
