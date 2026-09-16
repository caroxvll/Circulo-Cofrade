import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_upload_compress.dart';
import '../../shared/models/hermandad_scheduled_post.dart';
import 'data/forums_repository.dart';
import 'forums_provider.dart';
import 'hermandad_scheduled_posts_provider.dart';
import 'utils/official_post_categories.dart';
import 'widgets/forum_compose_field.dart';
import 'widgets/forum_compose_sheet_layout.dart';
import 'widgets/hermandad_official_compose_header.dart';
import 'widgets/hermandad_official_post_preview.dart';
import 'widgets/hermandad_post_image_picker.dart';
import 'widgets/official_post_categories_picker.dart';
import 'widgets/scheduled_post_datetime_picker.dart';

class HermandadScheduledPostsScreen extends ConsumerWidget {
  const HermandadScheduledPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(myHermandadPendingPostsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'BORRADORES Y PROGRAMADAS',
          style: AppTypography.screenAppBarTitle(),
        ),
        centerTitle: true,
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar tus publicaciones.\n'
              '¿Ejecutaste hermandad_scheduled_posts.sql y '
              'hermandad_scheduled_posts_drafts.sql?',
              style: AppTypography.bodyMedium(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (pending) {
          if (pending.isEmpty) return const _EmptyPendingPosts();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (pending.drafts.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Borradores',
                  count: pending.drafts.length,
                ),
                const SizedBox(height: 8),
                for (final post in pending.drafts) ...[
                  _DraftPostCard(post: post),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
              ],
              if (pending.scheduled.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Programadas',
                  count: pending.scheduled.length,
                ),
                const SizedBox(height: 8),
                for (final post in pending.scheduled) ...[
                  _ScheduledPostCard(post: post),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyPendingPosts extends StatelessWidget {
  const _EmptyPendingPosts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 48,
              color: AppColors.burgundy.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin borradores ni publicaciones programadas',
              style: AppTypography.titleLarge(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Desde el tablón de tu hermandad puedes guardar borradores '
              'o programar avisos oficiales.',
              style: AppTypography.bodyMedium(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTypography.titleLarge().copyWith(fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.burgundy.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: AppTypography.labelSmall(color: AppColors.burgundy),
          ),
        ),
      ],
    );
  }
}

class _PostCardShell extends StatelessWidget {
  const _PostCardShell({required this.post, required this.children});

  final HermandadScheduledPost post;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.topicTitle,
                  style: AppTypography.titleLarge().copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.burgundy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  officialCategoryLabel(post.officialCategory),
                  style: AppTypography.labelSmall(color: AppColors.burgundy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: AppTypography.bodyMedium(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DraftPostCard extends ConsumerWidget {
  const _DraftPostCard({required this.post});

  final HermandadScheduledPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatedLabel = post.updatedAt != null
        ? DateFormat("d MMM · HH:mm", 'es').format(post.updatedAt!)
        : null;

    return _PostCardShell(
      post: post,
      children: [
        if (updatedLabel != null)
          Row(
            children: [
              const Icon(Icons.edit_note, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Editado $updatedLabel',
                style: AppTypography.labelSmall(color: AppColors.textMuted),
              ),
            ],
          ),
        if (updatedLabel != null) const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton.icon(
              onPressed: () => _editDraft(context, ref),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
            TextButton.icon(
              onPressed: () => _scheduleDraft(context, ref),
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: const Text('Programar'),
            ),
            TextButton.icon(
              onPressed: () => _deleteDraft(context, ref),
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.accentRed),
              label: Text(
                'Eliminar',
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editDraft(BuildContext context, WidgetRef ref) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PendingPostEditSheet(post: post, mode: _EditMode.draft),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador actualizado')),
      );
    }
  }

  Future<void> _scheduleDraft(BuildContext context, WidgetRef ref) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PendingPostEditSheet(
        post: post,
        mode: _EditMode.scheduleDraft,
      ),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación programada')),
      );
    }
  }

  Future<void> _deleteDraft(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar borrador'),
        content: const Text('Se borrará este borrador de forma permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: AppTypography.bodyMedium(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(hermandadScheduledPostControllerProvider).deleteDraft(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Borrador eliminado')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el borrador')),
        );
      }
    }
  }
}

class _ScheduledPostCard extends ConsumerWidget {
  const _ScheduledPostCard({required this.post});

  final HermandadScheduledPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whenLabel = post.scheduledAt != null
        ? DateFormat("EEE d MMM · HH:mm", 'es').format(post.scheduledAt!)
        : '—';

    return _PostCardShell(
      post: post,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              whenLabel,
              style: AppTypography.labelSmall(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _editPost(context, ref),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            ),
            TextButton.icon(
              onPressed: () => _cancelPost(context, ref),
              icon: const Icon(Icons.close, size: 18, color: AppColors.accentRed),
              label: Text(
                'Cancelar',
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editPost(BuildContext context, WidgetRef ref) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PendingPostEditSheet(
        post: post,
        mode: _EditMode.scheduled,
      ),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación actualizada')),
      );
    }
  }

  Future<void> _cancelPost(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar publicación'),
        content: const Text(
          'Esta publicación no se publicará. ¿Quieres cancelarla?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancelar publicación',
              style: AppTypography.bodyMedium(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(hermandadScheduledPostControllerProvider).cancel(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicación cancelada')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar la publicación')),
        );
      }
    }
  }
}

enum _EditMode { draft, scheduleDraft, scheduled }

class _PendingPostEditSheet extends ConsumerStatefulWidget {
  const _PendingPostEditSheet({required this.post, required this.mode});

  final HermandadScheduledPost post;
  final _EditMode mode;

  @override
  ConsumerState<_PendingPostEditSheet> createState() =>
      _PendingPostEditSheetState();
}

class _PendingPostEditSheetState extends ConsumerState<_PendingPostEditSheet> {
  late final TextEditingController _controller;
  late String _category;
  late DateTime _scheduledAt;
  bool _submitting = false;
  String? _error;
  Uint8List? _imageBytes;
  String? _imageMime;
  String? _imageUrl;

  bool get _showsSchedulePicker =>
      widget.mode == _EditMode.scheduled ||
      widget.mode == _EditMode.scheduleDraft;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.post.content);
    _category = widget.post.officialCategory;
    _scheduledAt = widget.post.scheduledAt ?? defaultHermandadScheduleTime();
    _imageUrl = widget.post.imageUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _resolveImageUrl() async {
    if (_imageBytes == null) return _imageUrl;

    final repo = ref.read(forumsRepositoryProvider);
    return repo.uploadOfficialPostImage(
      topicId: widget.post.topicId,
      bytes: _imageBytes!,
      mimeType: _imageMime ?? 'image/jpeg',
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final hasImage = _imageBytes != null || (_imageUrl?.isNotEmpty ?? false);
    if (text.isEmpty && !hasImage) return;

    if (_showsSchedulePicker && !isValidHermandadScheduleTime(_scheduledAt)) {
      setState(
        () => _error = 'La fecha debe ser al menos 5 minutos en el futuro.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = ref.read(hermandadScheduledPostControllerProvider);

    try {
      final imageUrl = await _resolveImageUrl();
      switch (widget.mode) {
        case _EditMode.draft:
          await controller.updateDraft(
            id: widget.post.id,
            forumId: 'hermandades',
            content: text,
            officialCategory: _category,
            imageUrl: imageUrl,
          );
        case _EditMode.scheduleDraft:
          await controller.scheduleDraft(
            id: widget.post.id,
            forumId: 'hermandades',
            content: text,
            officialCategory: _category,
            scheduledAt: _scheduledAt,
            imageUrl: imageUrl,
          );
        case _EditMode.scheduled:
          await controller.updateScheduled(
            id: widget.post.id,
            forumId: 'hermandades',
            content: text,
            officialCategory: _category,
            scheduledAt: _scheduledAt,
            imageUrl: imageUrl,
          );
      }
      if (mounted) Navigator.pop(context, true);
    } on ImageTooLargeAfterCompressException {
      setState(() => _error = 'La imagen es demasiado grande.');
    } on OfficialPostImageTooLargeException {
      setState(() => _error = 'La imagen supera 5 MB.');
    } catch (_) {
      setState(() => _error = 'No se pudo guardar los cambios.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showPreview() async {
    final handle = ref.read(userHandleProvider);
    await showHermandadOfficialPostPreview(
      context,
      content: _controller.text,
      officialCategory: _category,
      authorHandle: handle,
      imageUrl: _imageUrl,
      imageBytes: _imageBytes,
    );
  }

  String get _title => switch (widget.mode) {
        _EditMode.draft => 'Editar borrador',
        _EditMode.scheduleDraft => 'Programar borrador',
        _EditMode.scheduled => 'Editar publicación',
      };

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
            _title,
            style: AppTypography.bodyMedium(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          OfficialPostCategoriesPicker(
            category: _category,
            onCategoryChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
          HermandadPostImagePicker(
            enabled: !_submitting,
            initialImageUrl: _imageUrl,
            onChanged: ({bytes, mimeType, existingUrl}) {
              setState(() {
                _imageBytes = bytes;
                _imageMime = mimeType;
                _imageUrl = existingUrl;
              });
            },
          ),
          const SizedBox(height: 12),
          ForumComposeField(
            controller: _controller,
            maxLines: 8,
            minLines: 6,
            toolbar: ForumComposeToolbar.editorial,
            hintText: 'Redacta la publicación…',
          ),
          if (_showsSchedulePicker) ...[
            const SizedBox(height: 12),
            ScheduledPostDatetimePicker(
              scheduledAt: _scheduledAt,
              onChanged: (value) => setState(() => _scheduledAt = value),
            ),
          ],
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
                    switch (widget.mode) {
                      _EditMode.draft => 'Guardar borrador',
                      _EditMode.scheduleDraft => 'Programar publicación',
                      _EditMode.scheduled =>
                        'Guardar en ${officialCategoryLabel(_category)}',
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

bool isValidHermandadScheduleTime(DateTime scheduledAt) {
  return scheduledAt.isAfter(
    DateTime.now().add(const Duration(minutes: 5)),
  );
}

DateTime defaultHermandadScheduleTime() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, 10, 0);
}
