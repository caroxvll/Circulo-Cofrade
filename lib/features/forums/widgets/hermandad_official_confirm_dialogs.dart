import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/official_post_categories.dart';

/// Confirma quitar el fijado de un comunicado oficial.
Future<bool> confirmUnpinOfficialPost(BuildContext context) {
  return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Quitar fijado?'),
          content: const Text(
            'El comunicado dejará de aparecer anclado arriba del tablón.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Quitar fijado'),
            ),
          ],
        ),
      ).then((value) => value ?? false);
}

/// Confirma fijar un comunicado (sustituye otro fijado si lo hay).
Future<bool> confirmPinOfficialPost(BuildContext context) {
  return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Fijar arriba del tablón?'),
          content: const Text(
            'Este comunicado quedará anclado bajo las pestañas. '
            'Si ya hay otro fijado, se sustituirá.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Fijar'),
            ),
          ],
        ),
      ).then((value) => value ?? false);
}

/// Confirma mover de sección un comunicado fijado.
Future<bool> confirmPinnedOfficialCategoryChange(
  BuildContext context, {
  required String fromCategory,
  required String toCategory,
}) {
  if (fromCategory == toCategory) return Future.value(true);

  return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Cambiar sección del fijado?'),
          content: Text(
            'Este comunicado está fijado arriba del tablón.\n\n'
            'Pasará de ${officialCategoryLabel(fromCategory)} a '
            '${officialCategoryLabel(toCategory)}. '
            'En «Todas» seguirá visible; en otras pestañas solo se anclará '
            'cuando coincida la sección.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Cambiar sección'),
            ),
          ],
        ),
      ).then((value) => value ?? false);
}

/// Confirma guardar cambios en un comunicado publicado.
Future<bool> confirmSaveOfficialPostEdit(BuildContext context) {
  return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Guardar cambios?'),
          content: const Text(
            'El comunicado publicado se actualizará en el tablón.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ).then((value) => value ?? false);
}
