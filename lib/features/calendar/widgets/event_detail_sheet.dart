import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/auth_provider.dart';
import '../calendar_provider.dart';
import '../utils/calendar_event_utils.dart';
import 'event_card.dart';
import 'event_compose_sheet.dart';

Future<void> showEventDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required CalendarEvent event,
  required DateTime focusedMonth,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _EventDetailSheet(
      event: event,
      focusedMonth: focusedMonth,
    ),
  );
}

class _EventDetailSheet extends ConsumerWidget {
  const _EventDetailSheet({
    required this.event,
    required this.focusedMonth,
  });

  final CalendarEvent event;
  final DateTime focusedMonth;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar evento?'),
        content: Text('Se borrará «${event.title}» del calendario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(calendarRepositoryProvider).deleteEvent(event.id!);
      invalidateCalendarMonth(ref, focusedMonth);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento eliminado')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el evento.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(isCalendarAdminProvider);
    final canManage = canManageCalendarEvent(
      event: event,
      currentUserId: userId,
      isAdmin: isAdmin,
    );
    final dateLabel =
        DateFormat("EEEE d 'de' MMMM", 'es').format(event.date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Detalle del evento', style: AppTypography.displaySmall()),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            dateLabel[0].toUpperCase() + dateLabel.substring(1),
            style: AppTypography.bodyMedium(color: AppColors.accentRed),
          ),
          const SizedBox(height: 12),
          EventCard(event: event, highlighted: true),
          if (event.publisherHandle != null) ...[
            const SizedBox(height: 12),
            Text(
              'Publicado por ${event.publisherHandle}',
              style: AppTypography.labelSmall(color: AppColors.textMuted),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await showEventComposeSheet(
                        context,
                        ref,
                        existing: event,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentRed,
                      side: const BorderSide(color: AppColors.accentRed),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
