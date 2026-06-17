import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(dialogTitle),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: [
                  for (final reason in reportReasons)
                    DropdownMenuItem(value: reason, child: Text(reason)),
                ],
                onChanged: (value) => setState(() => selected = value ?? selected),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalles (opcional)',
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enviar'),
        ),
      ],
    ),
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
