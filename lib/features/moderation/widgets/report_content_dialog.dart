import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/topic_detail_typography.dart';
import '../data/moderation_repository.dart';
import '../moderation_provider.dart';

const reportReasons = [
  'Spam',
  'Acoso',
  'Suplantación',
  'Contenido inapropiado',
  'Otro',
];

Future<void> submitContentReport({
  required BuildContext context,
  required WidgetRef ref,
  required String reporterId,
  required String targetType,
  required String targetId,
  required String dialogTitle,
}) async {
  var selected = reportReasons.first;
  final detailsController = TextEditingController();

  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.burgundy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.flag_outlined,
                        size: 18,
                        color: AppColors.burgundy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dialogTitle,
                            style: TopicDetailTypography.title().copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'La Junta revisará el aviso. Sé concreto si puedes.',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                            ).copyWith(fontSize: 11.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      tooltip: 'Cerrar',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Motivo',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selected,
                  borderRadius: BorderRadius.circular(12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.burgundy,
                        width: 1.2,
                      ),
                    ),
                  ),
                  style: AppTypography.bodyMedium(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                  items: [
                    for (final reason in reportReasons)
                      DropdownMenuItem(value: reason, child: Text(reason)),
                  ],
                  onChanged: (value) =>
                      setState(() => selected = value ?? selected),
                ),
                const SizedBox(height: 14),
                Text(
                  'Detalles (opcional)',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  style: AppTypography.bodyMedium(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'Cuéntanos qué ha pasado…',
                    hintStyle: AppTypography.bodyMedium(
                      color: AppColors.textMuted,
                    ).copyWith(fontSize: 13.5),
                    filled: true,
                    fillColor: AppColors.backgroundElevated,
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.9),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.burgundy,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.95),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: AppTypography.buttonLabel(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.burgundy,
                          foregroundColor: AppColors.textOnDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          'Enviar reporte',
                          style: AppTypography.buttonLabel().copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );

  final details = detailsController.text.trim();
  detailsController.dispose();

  if (submitted != true) return;

  try {
    await ref.read(moderationRepositoryProvider).reportContent(
          reporterId: reporterId,
          targetType: targetType,
          targetId: targetId,
          reason: selected,
          details: details,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado. Gracias.')),
      );
    }
  } on ModerationUnavailableException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el reporte.')),
      );
    }
  }
}
