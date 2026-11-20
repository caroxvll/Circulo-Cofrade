import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pick_gallery_image.dart';
import '../../forums/widgets/forum_compose_sheet_header.dart';
import '../../forums/widgets/forum_compose_sheet_layout.dart';
import '../data/historias_repository.dart';
import '../historias_provider.dart';
import '../models/historia.dart';

Future<bool> showHistoriaComposeSheet(BuildContext context) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => const _HistoriaComposeSheet(),
      ) ??
      false;
}

class _HistoriaComposeSheet extends ConsumerStatefulWidget {
  const _HistoriaComposeSheet();

  @override
  ConsumerState<_HistoriaComposeSheet> createState() =>
      _HistoriaComposeSheetState();
}

class _HistoriaComposeSheetState extends ConsumerState<_HistoriaComposeSheet> {
  final _title = TextEditingController();
  final _excerpt = TextEditingController();
  final _pages = <_PageDraft>[_PageDraft()];
  HistoriaKind _kind = HistoriaKind.cronica;
  Uint8List? _coverBytes;
  String _coverExtension = 'jpg';
  String _coverType = 'image/jpeg';
  var _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    for (final page in _pages) {
      page.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await pickGalleryImage(maxWidth: 1600, imageQuality: 88);
    if (image == null || !mounted) return;
    setState(() {
      _coverBytes = image.bytes;
      _coverExtension = image.extension;
      _coverType = image.contentType;
    });
  }

  void _addPage() {
    if (_pages.length >= 30) return;
    setState(() => _pages.add(_PageDraft()));
  }

  void _removePage(int index) {
    if (_pages.length <= 1) return;
    setState(() {
      _pages[index].dispose();
      _pages.removeAt(index);
    });
  }

  Future<void> _pickPageImage(int index) async {
    final image = await pickGalleryImage(maxWidth: 1600, imageQuality: 88);
    if (image == null || !mounted) return;
    setState(() {
      _pages[index].imageBytes = image.bytes;
      _pages[index].imageExtension = image.extension;
      _pages[index].imageType = image.contentType;
    });
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    final repo = ref.read(historiasRepositoryProvider);
    try {
      final historia = await repo.create(
        title: _title.text,
        excerpt: _excerpt.text,
        kind: _kind,
        pages: _pages
            .map(
              (p) => HistoriaPage(
                body: p.body.text.trim().isEmpty && p.imageBytes != null
                    ? ' '
                    : p.body.text,
              ),
            )
            .toList(),
      );
      final pages = <HistoriaPage>[];
      for (final draft in _pages) {
        String? imageUrl;
        final bytes = draft.imageBytes;
        if (bytes != null) {
          imageUrl = await repo.uploadPageImage(
            authorId: historia.authorId,
            historiaId: historia.id,
            bytes: bytes,
            extension: draft.imageExtension,
            contentType: draft.imageType,
          );
        }
        pages.add(
          HistoriaPage(
            body: draft.body.text,
            caption: draft.caption.text,
            imageUrl: imageUrl,
          ),
        );
      }
      var coverUrl = historia.coverImageUrl;
      final cover = _coverBytes;
      if (cover != null) {
        coverUrl = await repo.uploadCover(
          authorId: historia.authorId,
          historiaId: historia.id,
          bytes: cover,
          extension: _coverExtension,
          contentType: _coverType,
        );
      }
      await repo.updateHistoria(
        historiaId: historia.id,
        title: _title.text,
        excerpt: _excerpt.text,
        kind: _kind,
        pages: pages,
        coverImageUrl: coverUrl,
      );
      ref.invalidate(publishedHistoriasProvider);
      if (mounted) Navigator.pop(context, true);
    } on HistoriasValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo publicar. ¿Ejecutaste historias.sql y tienes sello de Cronista?',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ForumComposeSheetLayout(
      header: ForumComposeSheetTitleBar(
        closeEnabled: !_publishing,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Nueva historia',
                style: AppTypography.titleLarge(),
              ),
            ),
            TextButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Publicar',
                      style: AppTypography.bodyMedium(color: AppColors.burgundy)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Se lee como un libro: portada, páginas y comentarios en la ficha.',
            style: AppTypography.bodyMedium(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _publishing ? null : _pickCover,
              child: SizedBox(
                width: 132,
                height: 176,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: _coverBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 32,
                              color: AppColors.goldDark.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Portada',
                              style: AppTypography.labelSmall(
                                color: AppColors.goldDark,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_coverBytes!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in HistoriaKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: _publishing
                      ? null
                      : (_) => setState(() => _kind = kind),
                  selectedColor: AppColors.goldPale,
                  labelStyle: AppTypography.labelSmall(
                    color: AppColors.burgundy,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            enabled: !_publishing,
            maxLength: 80,
            style: AppTypography.newsHeadline(),
            decoration: const InputDecoration(
              hintText: 'Título',
              counterText: '',
              border: InputBorder.none,
            ),
          ),
          TextField(
            controller: _excerpt,
            enabled: !_publishing,
            maxLength: 280,
            maxLines: 3,
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            decoration: const InputDecoration(
              hintText: 'Entradilla que se lee en la estantería',
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _pages.length; i++) ...[
            Row(
              children: [
                Text(
                  'Página ${i + 1}',
                  style: AppTypography.sectionTitle(),
                ),
                const Spacer(),
                if (_pages.length > 1)
                  IconButton(
                    onPressed: _publishing ? null : () => _removePage(i),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            TextField(
              controller: _pages[i].body,
              enabled: !_publishing,
              maxLines: 8,
              minLines: 5,
              maxLength: 3500,
              style: AppTypography.bookBody(),
              decoration: InputDecoration(
                hintText: 'Escribe esta página…',
                filled: true,
                fillColor: const Color(0xFFF7F1E6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _publishing ? null : () => _pickPageImage(i),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(
                    _pages[i].imageBytes == null ? 'Foto' : 'Cambiar foto',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                  ),
                ),
                if (_pages[i].imageBytes != null) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      _pages[i].imageBytes!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    onPressed: _publishing
                        ? null
                        : () => setState(() => _pages[i].imageBytes = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ],
            ),
            if (_pages[i].imageBytes != null)
              TextField(
                controller: _pages[i].caption,
                enabled: !_publishing,
                maxLength: 120,
                style: AppTypography.bookCaption(),
                decoration: const InputDecoration(
                  hintText: 'Pie de foto (opcional)',
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (_pages.length < 30)
            OutlinedButton.icon(
              onPressed: _publishing ? null : _addPage,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir página'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                side: const BorderSide(color: AppColors.burgundy),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageDraft {
  final body = TextEditingController();
  final caption = TextEditingController();
  Uint8List? imageBytes;
  String imageExtension = 'jpg';
  String imageType = 'image/jpeg';

  void dispose() {
    body.dispose();
    caption.dispose();
  }
}
