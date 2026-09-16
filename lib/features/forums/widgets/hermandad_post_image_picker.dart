import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_upload_compress.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../data/forums_repository.dart';
import 'hermandad_compose_section_label.dart';

/// Selector de cartel o foto (publicaciones oficiales o portada de tema).
class HermandadPostImagePicker extends StatefulWidget {
  const HermandadPostImagePicker({
    super.key,
    this.initialImageUrl,
    this.enabled = true,
    this.onChanged,
    this.sectionTitle = 'IMAGEN',
    this.sectionSubtitle = 'Cartel, foto de procesión…',
    this.maxBytes = ForumsRepository.maxOfficialPostImageBytes,
  });

  final String? initialImageUrl;
  final bool enabled;
  final String sectionTitle;
  final String sectionSubtitle;
  final int maxBytes;
  final void Function({
    Uint8List? bytes,
    String? mimeType,
    String? existingUrl,
  })? onChanged;

  @override
  State<HermandadPostImagePicker> createState() =>
      _HermandadPostImagePickerState();
}

class _HermandadPostImagePickerState extends State<HermandadPostImagePicker> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String? _mimeType;
  String? _existingUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _existingUrl = widget.initialImageUrl?.trim().isNotEmpty == true
        ? widget.initialImageUrl
        : null;
  }

  @override
  void didUpdateWidget(covariant HermandadPostImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialImageUrl != widget.initialImageUrl && _bytes == null) {
      _existingUrl = widget.initialImageUrl?.trim().isNotEmpty == true
          ? widget.initialImageUrl
          : null;
    }
  }

  bool get _hasImage => _bytes != null || (_existingUrl?.isNotEmpty ?? false);

  void _notify() {
    widget.onChanged?.call(
      bytes: _bytes,
      mimeType: _mimeType,
      existingUrl: _bytes == null ? _existingUrl : null,
    );
  }

  Future<void> _pick() async {
    if (!widget.enabled || _busy) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final raw = await file.readAsBytes();
      final compressed = await compressImageForUploadAsync(
        raw,
        maxBytes: widget.maxBytes,
      );

      if (mounted && compressed.wasCompressed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imagen optimizada (${formatImageSize(raw.length)} → '
              '${formatImageSize(compressed.bytes.length)})',
            ),
          ),
        );
      }

      setState(() {
        _bytes = compressed.bytes;
        _mimeType = compressed.mimeType;
        _existingUrl = null;
      });
      _notify();
    } on ImageTooLargeAfterCompressException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La imagen sigue siendo demasiado grande. Prueba con otra más pequeña.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    setState(() {
      _bytes = null;
      _mimeType = null;
      _existingUrl = null;
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HermandadComposeSectionLabel(
          title: widget.sectionTitle,
          subtitle: widget.sectionSubtitle,
        ),
        const SizedBox(height: 8),
        if (_hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: _bytes != null
                    ? Image.memory(_bytes!, fit: BoxFit.contain)
                    : CofradeoNetworkImage(
                        url: _existingUrl!,
                        fit: BoxFit.contain,
                        cacheSize: MediaQuery.sizeOf(context)
                            .width
                            .clamp(320.0, 1080.0),
                        errorWidget: _emptySlot(),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: widget.enabled && !_busy ? _pick : null,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Cambiar'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.enabled && !_busy ? _remove : null,
                icon: Icon(Icons.delete_outline, size: 18, color: AppColors.accentRed),
                label: Text(
                  'Quitar',
                  style: AppTypography.bodyMedium(color: AppColors.accentRed),
                ),
              ),
            ],
          ),
        ] else
          OutlinedButton.icon(
            onPressed: widget.enabled && !_busy ? _pick : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Añadir imagen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.burgundy,
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _emptySlot() {
    return Container(
      color: AppColors.backgroundElevated,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.textMuted.withValues(alpha: 0.7),
      ),
    );
  }
}
