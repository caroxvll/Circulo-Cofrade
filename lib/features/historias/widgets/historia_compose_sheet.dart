import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pick_gallery_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../forums/widgets/forum_compose_sheet_header.dart';
import '../../forums/widgets/forum_compose_sheet_layout.dart';
import '../../forums/widgets/scheduled_post_datetime_picker.dart';
import '../data/historias_repository.dart';
import '../historias_provider.dart';
import '../models/historia.dart';

Future<bool> showHistoriaPublishSheet(
  BuildContext context, {
  Historia? existing,
  HistoriaKind? kind,
}) async {
  if (existing != null) {
    return showHistoriaComposeSheet(context, existing: existing);
  }
  final picked = kind ?? await showHistoriaKindPicker(context);
  if (picked == null || !context.mounted) return false;
  return showHistoriaComposeSheet(context, initialKind: picked);
}

Future<HistoriaKind?> showHistoriaKindPicker(BuildContext context) {
  return showModalBottomSheet<HistoriaKind>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _HistoriaKindPicker(),
  );
}

Future<bool> showHistoriaComposeSheet(
  BuildContext context, {
  HistoriaKind? initialKind,
  Historia? existing,
}) async {
  var ready = existing;
  if (ready != null && ready.pages.isEmpty) {
    ready = await ProviderScope.containerOf(context)
        .read(historiasRepositoryProvider)
        .fetchById(ready.id);
    if (ready == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir para editar.')),
        );
      }
      return false;
    }
  }
  if (!context.mounted) return false;
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
        builder: (_) => _HistoriaComposeSheet(
          initialKind: initialKind ?? ready?.kind ?? HistoriaKind.libro,
          existing: ready,
        ),
      ) ??
      false;
}

IconData historiaKindIcon(HistoriaKind kind) => switch (kind) {
      HistoriaKind.libro => Icons.menu_book_outlined,
      HistoriaKind.articulo => Icons.article_outlined,
    };

class _HistoriaKindPicker extends StatelessWidget {
  const _HistoriaKindPicker();

  @override
  Widget build(BuildContext context) {
    return ForumComposeSheetLayout(
      header: ForumComposeSheetTitleBar(
        title: Text(
          '¿Qué quieres publicar?',
          style: AppTypography.titleLarge(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'En El Cronicón. Libro o artículo: elige el formato y luego escribes.',
            style: AppTypography.bodyMedium(),
          ),
          const SizedBox(height: 16),
          for (final kind in HistoriaKind.values) ...[
            _KindOptionTile(
              kind: kind,
              headline: kind.publishLabel,
              selected: false,
              showChevron: true,
              onTap: () => Navigator.pop(context, kind),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _KindOptionTile extends StatelessWidget {
  const _KindOptionTile({
    required this.kind,
    required this.headline,
    required this.selected,
    required this.onTap,
    this.showChevron = false,
  });

  final HistoriaKind kind;
  final String headline;
  final bool selected;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.goldPale : AppColors.backgroundElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? AppColors.gold
              : AppColors.gold.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Icon(
                historiaKindIcon(kind),
                color: AppColors.burgundy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: AppTypography.titleLarge().copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kind.blurb,
                      style: AppTypography.bodyMedium(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.goldDark.withValues(alpha: 0.8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoriaComposeSheet extends ConsumerStatefulWidget {
  const _HistoriaComposeSheet({
    required this.initialKind,
    this.existing,
  });

  final HistoriaKind initialKind;
  final Historia? existing;

  @override
  ConsumerState<_HistoriaComposeSheet> createState() =>
      _HistoriaComposeSheetState();
}

class _HistoriaComposeSheetState extends ConsumerState<_HistoriaComposeSheet> {
  late final TextEditingController _title;
  late final TextEditingController _excerpt;
  late final List<_PageDraft> _pages;
  late HistoriaKind _kind;
  Uint8List? _coverBytes;
  String _coverExtension = 'jpg';
  String _coverType = 'image/jpeg';
  String? _existingCoverUrl;
  var _saving = false;
  var _schedule = false;
  late DateTime _scheduledAt;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = widget.initialKind;
    _title = TextEditingController(text: existing?.title ?? '');
    _excerpt = TextEditingController(text: existing?.excerpt ?? '');
    _existingCoverUrl = existing?.coverImageUrl;
    _schedule = existing?.isScheduled == true;
    _scheduledAt = existing?.scheduledAt ?? _defaultScheduleAt();
    final pages = existing?.pages ?? const <HistoriaPage>[];
    _pages = pages.isEmpty
        ? [_PageDraft()]
        : pages
            .map(
              (page) => _PageDraft()
                ..body.text = page.body
                ..caption.text = page.caption ?? ''
                ..imageUrl = page.imageUrl,
            )
            .toList();
  }

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

  void _invalidateLists({String? historiaId}) {
    ref.invalidate(publishedHistoriasFeedProvider);
    ref.invalidate(publishedHistoriasProvider);
    ref.invalidate(myHistoriasProvider);
    ref.invalidate(staffHistoriasProvider);
    ref.invalidate(publishedHistoriasByAuthorProvider);
    if (historiaId != null) {
      ref.invalidate(historiaByIdProvider(historiaId));
    }
  }

  DateTime _defaultScheduleAt() {
    final soon = DateTime.now().add(const Duration(hours: 2));
    return DateTime(soon.year, soon.month, soon.day, soon.hour);
  }

  Future<void> _save({required String status}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(historiasRepositoryProvider);
    try {
      var historia = widget.existing;
      historia ??= await repo.create(
        title: _title.text,
        excerpt: _excerpt.text,
        kind: _kind,
        status: status,
        scheduledAt: status == 'scheduled' ? _scheduledAt : null,
        pages: _pages
            .map(
              (p) => HistoriaPage(
                body: p.body.text.trim().isEmpty && p.hasImage ? ' ' : p.body.text,
                imageUrl: p.imageUrl,
                caption: p.caption.text,
              ),
            )
            .toList(),
      );
      final pages = <HistoriaPage>[];
      for (final draft in _pages) {
        var imageUrl = draft.imageUrl;
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
      var coverUrl = _existingCoverUrl ?? historia.coverImageUrl;
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
        status: status,
        pages: pages,
        coverImageUrl: coverUrl,
        scheduledAt: status == 'scheduled' ? _scheduledAt : null,
      );
      _invalidateLists(historiaId: historia.id);
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
              'No se pudo guardar. Revisa que el SQL de Historias esté ejecutado.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return ForumComposeSheetLayout(
      header: ForumComposeSheetTitleBar(
        closeEnabled: !_saving,
        title: Text(
          editing
              ? (widget.existing!.isDraft
                  ? 'Seguir escribiendo'
                  : 'Editar ${_kind.label.toLowerCase()}')
              : _kind.composeTitle,
          style: AppTypography.titleLarge(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _kind.blurb,
            style: AppTypography.bodyMedium(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in HistoriaKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  showCheckmark: false,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _kind = kind),
                  selectedColor: AppColors.goldPale,
                  avatar: Icon(
                    historiaKindIcon(kind),
                    size: 16,
                    color: AppColors.burgundy,
                  ),
                  labelStyle: AppTypography.labelSmall(
                    color: AppColors.burgundy,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _saving ? null : _pickCover,
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
                  child: _coverPreview(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            enabled: !_saving,
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
            enabled: !_saving,
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
                    onPressed: _saving ? null : () => _removePage(i),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            TextField(
              controller: _pages[i].body,
              enabled: !_saving,
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
                  onPressed: _saving ? null : () => _pickPageImage(i),
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(
                    _pages[i].hasImage ? 'Cambiar foto' : 'Foto',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.burgundy,
                  ),
                ),
                if (_pages[i].hasImage) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: _pages[i].imageBytes != null
                          ? Image.memory(
                              _pages[i].imageBytes!,
                              fit: BoxFit.cover,
                            )
                          : CofradeoNetworkImage(
                              url: _pages[i].imageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _pages[i].imageBytes = null;
                              _pages[i].imageUrl = null;
                            }),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ],
            ),
            if (_pages[i].hasImage)
              TextField(
                controller: _pages[i].caption,
                enabled: !_saving,
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
              onPressed: _saving ? null : _addPage,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir página'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                side: const BorderSide(color: AppColors.burgundy),
              ),
            ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _saving ? null : () => _save(status: 'draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: const BorderSide(color: AppColors.burgundy),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Guardar borrador'),
          ),
          const SizedBox(height: 8),
          if (_schedule) ...[
            ScheduledPostDatetimePicker(
              scheduledAt: _scheduledAt,
              onChanged: (when) => setState(() => _scheduledAt = when),
              actionLabel: 'Sale',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : () => _save(status: 'scheduled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                side: const BorderSide(color: AppColors.burgundy),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Programar ${_kind.label.toLowerCase()}'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _schedule = false),
              child: const Text('Publicar ahora, sin fecha'),
            ),
          ] else
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _schedule = true;
                        _scheduledAt = _defaultScheduleAt();
                      }),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                side: const BorderSide(color: AppColors.burgundy),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Programar'),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : () => _save(status: 'published'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.burgundy,
              foregroundColor: AppColors.textOnDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.existing?.isPublished == true
                        ? 'Guardar cambios'
                        : _kind.publishLabel,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _coverPreview() {
    if (_coverBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(_coverBytes!, fit: BoxFit.cover),
      );
    }
    final url = _existingCoverUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CofradeoNetworkImage(url: url, fit: BoxFit.cover),
      );
    }
    return Column(
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
    );
  }
}

class _PageDraft {
  final body = TextEditingController();
  final caption = TextEditingController();
  Uint8List? imageBytes;
  String? imageUrl;
  String imageExtension = 'jpg';
  String imageType = 'image/jpeg';

  bool get hasImage => imageBytes != null || (imageUrl ?? '').trim().isNotEmpty;

  void dispose() {
    body.dispose();
    caption.dispose();
  }
}
