import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

const imageCreditMaxLength = 160;

String? sanitizeImageCredit(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  return text.length > imageCreditMaxLength
      ? text.substring(0, imageCreditMaxLength)
      : text;
}

String formatImageCredit(String credit) {
  final text = credit.trim();
  if (text.isEmpty) return '';
  final lower = text.toLowerCase();
  if (lower.startsWith('foto') ||
      lower.startsWith('imagen') ||
      lower.startsWith('fuente') ||
      lower.startsWith('archivo') ||
      lower.startsWith('©') ||
      lower.startsWith('(c)')) {
    return text;
  }
  return 'Foto: $text';
}

/// Pie legal bajo una imagen (fotógrafo, archivo, web…).
class ImageSourceCredit extends StatelessWidget {
  const ImageSourceCredit({
    super.key,
    required this.credit,
    this.onDark = false,
    this.align = TextAlign.start,
  });

  final String? credit;
  final bool onDark;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final raw = sanitizeImageCredit(credit);
    if (raw == null) return const SizedBox.shrink();
    return Text(
      formatImageCredit(raw),
      textAlign: align,
      style: AppTypography.labelSmall(
        color: onDark ? AppColors.goldPale : AppColors.textMuted,
      ).copyWith(
        fontSize: 11.5,
        fontStyle: FontStyle.italic,
        height: 1.3,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class ImageSourceCreditField extends StatelessWidget {
  const ImageSourceCreditField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: imageCreditMaxLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Origen de la imagen',
        hintText: 'Archivo de la hermandad, fotógrafo, web…',
        helperText: 'Para el copyright. Se ve debajo de la foto.',
        counterText: '',
      ),
    );
  }
}
