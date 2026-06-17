import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../data/reply_moderation_exception.dart';
import '../forums_provider.dart';
import 'mention_autocomplete_field.dart';

Future<void> showReplyEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  required String topicId,
  required ForumReply reply,
}) async {
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _ReplyEditSheet(
        forumId: forumId,
        topicId: topicId,
        reply: reply,
      );
    },
  );
}

class _ReplyEditSheet extends ConsumerStatefulWidget {
  const _ReplyEditSheet({
    required this.forumId,
    required this.topicId,
    required this.reply,
  });

  final String forumId;
  final String topicId;
  final ForumReply reply;

  @override
  ConsumerState<_ReplyEditSheet> createState() => _ReplyEditSheetState();
}

class _ReplyEditSheetState extends ConsumerState<_ReplyEditSheet> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reply.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(
            replyEditControllerProvider(
              ReplyEditTarget(
                forumId: widget.forumId,
                topicId: widget.topicId,
                replyId: widget.reply.id,
              ),
            ),
          )
          .update(text);

      if (mounted) Navigator.pop(context);
    } on ReplyModerationException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (_) {
      setState(
        () => _error =
            'No se pudo guardar. ¿Ejecutaste forum_reply_edit_delete.sql?',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Editar respuesta', style: AppTypography.displaySmall()),
          const SizedBox(height: 6),
          Text(
            'Solo durante 30 minutos y si nadie ha respondido debajo.',
            style: AppTypography.bodyMedium(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          MentionAutocompleteField(
            controller: _controller,
            hintText: 'Corrige tu mensaje…',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.bodyMedium(color: AppColors.accentRed),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

Future<bool?> confirmSoftDeleteReply(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar comentario'),
      content: const Text(
        'El comentario se ocultará para el resto de usuarios, pero '
        'permanece registrado por si fue reportado o la Junta debe revisarlo.\n\n'
        '¿Quieres continuar?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.burgundy,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}
