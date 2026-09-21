import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../../admin/admin_provider.dart';
import '../../auth/auth_provider.dart';
import '../../permissions/permissions_provider.dart';
import '../forums_provider.dart';
import '../utils/forum_navigation.dart';
import '../utils/noticias_forum.dart';

Future<void> showTopicModerationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  required ForumTopic topic,
}) async {
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _TopicModerationSheet(forumId: forumId, topic: topic),
  );
}

class _TopicModerationSheet extends ConsumerStatefulWidget {
  const _TopicModerationSheet({required this.forumId, required this.topic});

  final String forumId;
  final ForumTopic topic;

  @override
  ConsumerState<_TopicModerationSheet> createState() =>
      _TopicModerationSheetState();
}

class _TopicModerationSheetState extends ConsumerState<_TopicModerationSheet> {
  var _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      invalidateTopicData(
        ref,
        forumId: widget.forumId,
        topicId: widget.topic.id,
      );
      ref.invalidate(forumTopicsProvider(widget.forumId));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePin() async {
    final topic = widget.topic;
    if (topic.isSystem) return;
    final isNoticias = isNoticiasForum(widget.forumId);

    await _run(
      () => ref.read(adminRepositoryProvider).setTopicPinned(
            topicId: topic.id,
            isPinned: !topic.isPinned,
          ),
      topic.isPinned
          ? (isNoticias ? 'Noticia ya no destacada' : 'Tema desfijado')
          : (isNoticias ? 'Noticia destacada' : 'Tema fijado'),
    );
  }

  Future<void> _closeTopic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar este hilo?'),
        content: const Text(
          'El tema dejará de admitir respuestas nuevas. Puedes reabrirlo más tarde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(
      () => ref.read(adminRepositoryProvider).closeTopic(widget.topic.id),
      'Tema cerrado',
    );
  }

  Future<void> _reopenTopic() async {
    await _run(
      () => ref.read(adminRepositoryProvider).reopenTopic(widget.topic.id),
      'Tema reabierto',
    );
  }

  Future<void> _deleteTopic() async {
    final topic = widget.topic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar «${topic.title}»?'),
        content: const Text(
          'Se borrará el tema y todas sus respuestas de la base de datos. '
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

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).deleteTopic(topic.id);
      ref.invalidate(forumTopicsProvider(widget.forumId));
      ref.invalidate(rejectedTopicsProvider);
      if (!mounted) return;
      Navigator.pop(context); // cierra el sheet
      popForumTopic(context, forumId: widget.forumId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«${topic.title}» eliminado')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el tema')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _banAuthor() async {
    final authorId = widget.topic.authorId;
    if (authorId == null) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Expulsar a ${widget.topic.authorHandle}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No podrá participar en este foro. No es una suspensión global.',
              style: AppTypography.bodyMedium(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
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
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(permissionsRepositoryProvider).banFromForum(
            profileId: authorId,
            forumId: widget.forumId,
            reason: reason,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.topic.authorHandle} expulsado del foro'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo expulsar del foro')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final canBanAuthor = topic.authorId != null &&
        topic.authorId != currentUserId &&
        !topic.isSystem;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Moderar tema', style: AppTypography.displaySmall()),
          const SizedBox(height: 4),
          Text(
            topic.title,
            style: AppTypography.bodyMedium(color: AppColors.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          if (!topic.isSystem)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isNoticiasForum(widget.forumId)
                    ? (topic.isPinned
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded)
                    : (topic.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined),
                color: AppColors.burgundy,
              ),
              title: Text(
                isNoticiasForum(widget.forumId)
                    ? (topic.isPinned
                        ? 'Quitar de destacadas'
                        : 'Destacar noticia')
                    : (topic.isPinned ? 'Quitar fijado' : 'Fijar tema'),
              ),
              subtitle: Text(
                isNoticiasForum(widget.forumId)
                    ? (topic.isPinned
                        ? 'Deja de aparecer en Noticias destacadas'
                        : 'Mostrar arriba en Noticias destacadas')
                    : (topic.isPinned
                        ? 'Deja de aparecer arriba del foro'
                        : 'Mantener visible arriba del foro'),
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              onTap: _busy ? null : _togglePin,
            ),
          if (!topic.isClosed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: AppColors.burgundy),
              title: const Text('Cerrar hilo'),
              subtitle: Text(
                'Bloquea nuevas respuestas',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              onTap: _busy ? null : _closeTopic,
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_open_outlined, color: AppColors.burgundy),
              title: const Text('Reabrir hilo'),
              onTap: _busy ? null : _reopenTopic,
            ),
          if (canBanAuthor)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_off_outlined, color: AppColors.accentRed),
              title: Text('Expulsar ${topic.authorHandle} del foro'),
              subtitle: Text(
                'Solo afecta a este foro',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              onTap: _busy ? null : _banAuthor,
            ),
          if (!topic.isSystem)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: AppColors.accentRed),
              title: const Text('Eliminar tema'),
              subtitle: Text(
                'Borra el hilo y sus respuestas de la base de datos',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              onTap: _busy ? null : _deleteTopic,
            ),
        ],
      ),
    );
  }
}
