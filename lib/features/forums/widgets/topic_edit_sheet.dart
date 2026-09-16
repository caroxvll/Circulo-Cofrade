import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_text_format.dart';
import '../../../shared/models/forum.dart';
import '../data/forums_repository.dart';
import '../forums_provider.dart';
import 'forum_compose_field.dart';
import 'forum_compose_sheet_header.dart';
import 'forum_compose_sheet_layout.dart';
import 'hermandad_post_image_picker.dart';

Future<void> showTopicEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required String forumId,
  required ForumTopic topic,
}) async {
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _TopicEditSheet(forumId: forumId, topic: topic),
  );
}

class _TopicEditSheet extends ConsumerStatefulWidget {
  const _TopicEditSheet({required this.forumId, required this.topic});

  final String forumId;
  final ForumTopic topic;

  @override
  ConsumerState<_TopicEditSheet> createState() => _TopicEditSheetState();
}

class _TopicEditSheetState extends ConsumerState<_TopicEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  Uint8List? _coverBytes;
  String? _coverMimeType;
  String? _coverUrl;
  var _submitting = false;
  String? _error;

  bool get _isHermandades => widget.forumId == 'hermandades';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.topic.title);
    _bodyController = TextEditingController(text: widget.topic.body);
    final existing = widget.topic.coverImageUrl?.trim();
    _coverUrl =
        (existing != null && existing.isNotEmpty && !existing.startsWith('assets/'))
            ? existing
            : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<String?> _resolveCoverUrl() async {
    if (_coverBytes == null) return _coverUrl;
    return ref.read(forumsRepositoryProvider).uploadTopicCover(
          topicId: widget.topic.id,
          bytes: _coverBytes!,
          mimeType: _coverMimeType ?? 'image/jpeg',
        );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.length < 3 || body.isEmpty) {
      setState(() => _error = 'El título y el mensaje son obligatorios.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final excerpt = plainTextForExcerpt(body);
      final coverUrl = await _resolveCoverUrl();
      await ref.read(forumsRepositoryProvider).updateTopicAsOwner(
            topicId: widget.topic.id,
            title: title,
            body: body,
            excerpt: excerpt,
            coverImageUrl: coverUrl ?? '',
          );
      invalidateTopicData(
        ref,
        forumId: widget.forumId,
        topicId: widget.topic.id,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tema actualizado')),
        );
      }
    } on TopicCoverTooLargeException {
      if (mounted) {
        setState(
          () => _error =
              'La imagen es demasiado grande. Prueba con otra más ligera.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar los cambios.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForumComposeSheetLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ForumComposeSheetTitleBar(
            closeEnabled: !_submitting,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar tema',
                  style: AppTypography.displaySmall(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Como titular del hilo puedes ajustar título, mensaje y portada.',
                  style: AppTypography.bodyMedium(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
            maxLength: 120,
          ),
          const SizedBox(height: 12),
          ForumComposeField(
            controller: _bodyController,
            maxLines: 10,
            minLines: 5,
            toolbar: _isHermandades
                ? ForumComposeToolbar.editorial
                : ForumComposeToolbar.standard,
            hintText: _isHermandades
                ? 'Mensaje principal de la publicación…'
                : 'Mensaje principal del hilo…',
          ),
          const SizedBox(height: 16),
          HermandadPostImagePicker(
            enabled: !_submitting,
            initialImageUrl: _coverUrl,
            sectionTitle: 'PORTADA',
            sectionSubtitle: 'Opcional · cartel, foto…',
            maxBytes: ForumsRepository.maxTopicCoverBytes,
            onChanged: ({bytes, mimeType, existingUrl}) {
              setState(() {
                _coverBytes = bytes;
                _coverMimeType = mimeType;
                _coverUrl = existingUrl;
              });
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppTypography.bodyMedium(color: AppColors.accentRed)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
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
