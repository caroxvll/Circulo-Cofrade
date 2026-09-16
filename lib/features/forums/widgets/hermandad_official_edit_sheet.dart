import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../data/forums_repository.dart';
import '../data/reply_moderation_exception.dart';
import '../forums_provider.dart';
import '../topic_detail_typography.dart';
import '../utils/official_post_categories.dart';
import 'forum_compose_field.dart';
import 'forum_compose_sheet_layout.dart';
import 'hermandad_official_compose_header.dart';
import 'hermandad_official_confirm_dialogs.dart';
import 'hermandad_official_post_preview.dart';
import 'hermandad_post_image_picker.dart';
import 'official_post_categories_picker.dart';
import '../../../shared/models/forum.dart';

Future<void> showHermandadOfficialEditSheet(
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
    isDismissible: true,
    enableDrag: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return _HermandadOfficialEditSheet(
        forumId: forumId,
        topicId: topicId,
        reply: reply,
      );
    },
  );
}

class _HermandadOfficialEditSheet extends ConsumerStatefulWidget {
  const _HermandadOfficialEditSheet({
    required this.forumId,
    required this.topicId,
    required this.reply,
  });

  final String forumId;
  final String topicId;
  final ForumReply reply;

  @override
  ConsumerState<_HermandadOfficialEditSheet> createState() =>
      _HermandadOfficialEditSheetState();
}

class _HermandadOfficialEditSheetState
    extends ConsumerState<_HermandadOfficialEditSheet> {
  late final TextEditingController _controller;
  late String _officialCategory;
  bool _submitting = false;
  String? _error;
  Uint8List? _imageBytes;
  String? _imageMime;
  String? _imageUrl;
  var _clearImage = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.reply.content);
    _officialCategory = widget.reply.officialCategory ?? 'noticia';
    _imageUrl = widget.reply.imageUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _resolveImageUrl() async {
    if (_clearImage) return null;
    if (_imageBytes == null) return _imageUrl;

    final repo = ref.read(forumsRepositoryProvider);
    return repo.uploadOfficialPostImage(
      topicId: widget.topicId,
      bytes: _imageBytes!,
      mimeType: _imageMime ?? 'image/jpeg',
    );
  }

  Future<void> _showPreview() async {
    final handle = ref.read(userHandleProvider);
    await showHermandadOfficialPostPreview(
      context,
      content: _controller.text,
      officialCategory: _officialCategory,
      authorHandle: handle,
      imageUrl: _clearImage ? null : _imageUrl,
      imageBytes: _imageBytes,
      isFeatured: widget.reply.isFeatured,
    );
  }

  bool get _hasChanges {
    final originalCategory = widget.reply.officialCategory ?? 'noticia';
    final textChanged = _controller.text.trim() != widget.reply.content.trim();
    final categoryChanged = _officialCategory != originalCategory;
    final imageChanged = _clearImage || _imageBytes != null;
    return textChanged || categoryChanged || imageChanged;
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final hasImage =
        !_clearImage && (_imageBytes != null || (_imageUrl?.isNotEmpty ?? false));
    if (text.isEmpty && !hasImage) return;

    if (!_hasChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (widget.reply.isFeatured) {
      final originalCategory = widget.reply.officialCategory ?? 'noticia';
      if (_officialCategory != originalCategory) {
        final ok = await confirmPinnedOfficialCategoryChange(
          context,
          fromCategory: originalCategory,
          toCategory: _officialCategory,
        );
        if (!ok || !mounted) return;
      }
    }

    final save = await confirmSaveOfficialPostEdit(context);
    if (!save || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final imageUrl = await _resolveImageUrl();
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
          .updateOfficial(
            content: text,
            officialCategory: _officialCategory,
            imageUrl: imageUrl,
            clearImage: _clearImage,
          );

      if (mounted) Navigator.pop(context);
    } on ReplyModerationException catch (e) {
      setState(() => _error = e.userMessage);
    } on ImageTooLargeAfterCompressException {
      setState(() => _error = 'La imagen es demasiado grande.');
    } on OfficialPostImageTooLargeException {
      setState(() => _error = 'La imagen supera 5 MB.');
    } catch (_) {
      setState(
        () => _error =
            'No se pudo guardar. ¿Ejecutaste hermandad_official_edit.sql?',
      );
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
          HermandadOfficialComposeHeader(closeEnabled: !_submitting),
          const SizedBox(height: 6),
          Text(
            'Editar comunicado publicado',
            style: TopicDetailTypography.meta(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          OfficialPostCategoriesPicker(
            category: _officialCategory,
            onCategoryChanged: (value) {
              setState(() => _officialCategory = value);
            },
          ),
          const SizedBox(height: 10),
          HermandadPostImagePicker(
            enabled: !_submitting,
            initialImageUrl: _clearImage ? null : _imageUrl,
            onChanged: ({bytes, mimeType, existingUrl}) {
              setState(() {
                _imageBytes = bytes;
                _imageMime = mimeType;
                if (bytes != null) {
                  _clearImage = false;
                  _imageUrl = null;
                } else if (existingUrl != null) {
                  _clearImage = false;
                  _imageUrl = existingUrl;
                } else {
                  _clearImage = true;
                  _imageUrl = null;
                }
              });
            },
          ),
          const SizedBox(height: 10),
          ForumComposeField(
            controller: _controller,
            maxLines: 8,
            minLines: 6,
            toolbar: ForumComposeToolbar.editorial,
            hintText: 'Corrige el comunicado…',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTypography.bodyMedium(color: AppColors.accentRed),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _showPreview,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Vista previa'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
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
                : Text(
                    'Guardar en ${officialCategoryLabel(_officialCategory)}',
                  ),
          ),
        ],
      ),
    );
  }
}
