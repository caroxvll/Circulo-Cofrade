import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../auth/auth_provider.dart';
import '../calendar_provider.dart';
import '../data/calendar_repository.dart';
import '../models/organizer_logo.dart';
import '../../../shared/models/calendar_event.dart';

Future<bool?> showOrganizerLogoEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required OrganizerLogo item,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _OrganizerLogoEditSheet(item: item),
  );
}

class _OrganizerLogoEditSheet extends ConsumerStatefulWidget {
  const _OrganizerLogoEditSheet({required this.item});

  final OrganizerLogo item;

  @override
  ConsumerState<_OrganizerLogoEditSheet> createState() =>
      _OrganizerLogoEditSheetState();
}

class _OrganizerLogoEditSheetState extends ConsumerState<_OrganizerLogoEditSheet> {
  late final TextEditingController _labelController;
  var _saving = false;
  var _processingPick = false;
  String? _error;
  String? _logoUrl;
  String? _selectedExtension;
  String? _selectedContentType;
  Uint8List? _selectedBytes;
  String? _selectedName;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.item.displayLabel);
    _logoUrl = widget.item.logoUrl;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  String? _contentTypeForExtension(String extension) {
    return switch (extension) {
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
  }

  Future<void> _pickLogo() async {
    if (_processingPick || _saving) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['svg', 'png', 'webp', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    final extension = (file.extension ?? '').toLowerCase();
    final contentType = _contentTypeForExtension(extension);
    if (contentType == null) {
      setState(() => _error = 'El escudo debe ser SVG, PNG, WebP o JPG.');
      return;
    }
    if (bytes.length > ImageUploadLimits.eventIconPickMaxBytes) {
      setState(
        () => _error = 'El escudo es demasiado grande. Prueba con otra imagen.',
      );
      return;
    }

    setState(() {
      _processingPick = true;
      _error = null;
    });

    try {
      final prepared = await prepareImageUploadAsync(
        rawBytes: bytes,
        extension: extension,
        contentType: contentType,
        maxBytes: ImageUploadLimits.eventIconMaxBytes,
        maxSide: ImageUploadLimits.eventIconMaxSide,
      );
      if (!mounted) return;

      if (prepared.wasCompressed && prepared.originalBytes != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imagen optimizada (${formatImageSize(prepared.originalBytes!)} → '
              '${formatImageSize(prepared.bytes.length)})',
            ),
          ),
        );
      }

      setState(() {
        _selectedBytes = prepared.bytes;
        _selectedName = file.name;
        _selectedExtension = prepared.extension;
        _selectedContentType = prepared.contentType;
        _logoUrl = null;
        _processingPick = false;
      });
    } on ImageTooLargeAfterCompressException {
      if (mounted) {
        setState(() {
          _error = 'El escudo es demasiado grande. Prueba con otra imagen.';
          _processingPick = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo procesar el escudo.';
          _processingPick = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.length < 3) {
      setState(() => _error = 'El nombre debe tener al menos 3 caracteres.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(calendarRepositoryProvider);
      var logoUrl = _logoUrl;

      if (_selectedBytes != null &&
          _selectedExtension != null &&
          _selectedContentType != null) {
        logoUrl = await repo.uploadEventIcon(
          userId: user.id,
          bytes: _selectedBytes!,
          extension: _selectedExtension!,
          contentType: _selectedContentType!,
        );
      }

      await repo.updateOrganizerLogo(
        userId: user.id,
        organizerKey: widget.item.organizerKey,
        displayLabel: label,
        logoUrl: logoUrl,
        propagateToAllEvents: ref.read(isCalendarAdminProvider),
      );

      invalidateCalendarData(ref, DateTime.now());
      invalidateOrganizerLogos(ref);

      if (mounted) Navigator.pop(context, true);
    } on CalendarOrganizerLogoValidationException {
      setState(() => _error = 'Datos del escudo no válidos.');
    } on CalendarIconTooLargeException {
      setState(() => _error = 'El escudo no puede superar 1 MB.');
    } on ImageTooLargeAfterCompressException {
      setState(() => _error = 'El escudo es demasiado grande. Prueba con otra imagen.');
    } catch (_) {
      setState(() => _error = 'No se pudo guardar el escudo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, cofradeoSheetBottomPadding(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Editar escudo',
                    style: AppTypography.displaySmall(),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.burgundy),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Hermandad / organizador',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _LogoPreview(
                  size: 56,
                  logoUrl: _logoUrl,
                  pickedBytes: _selectedBytes,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || _processingPick ? null : _pickLogo,
                    icon: _processingPick
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_outlined, size: 18),
                    label: Text(
                      _processingPick
                          ? 'Optimizando…'
                          : (_selectedName ?? 'Cambiar escudo'),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTypography.bodyMedium(color: AppColors.accentRed),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.size,
    required this.logoUrl,
    required this.pickedBytes,
  });

  final double size;
  final String? logoUrl;
  final Uint8List? pickedBytes;

  @override
  Widget build(BuildContext context) {
    if (pickedBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.memory(pickedBytes!, width: size, height: size, fit: BoxFit.cover),
      );
    }

    return EventTypeIcon(
      type: EventType.evento,
      size: size,
      customIconUrl: logoUrl,
    );
  }
}
