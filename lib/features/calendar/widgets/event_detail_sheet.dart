import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../auth/auth_provider.dart';
import '../calendar_provider.dart';
import '../utils/calendar_event_utils.dart';
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
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EventDetailSheet(event: event, focusedMonth: focusedMonth),
  );
}

class _EventDetailSheet extends ConsumerWidget {
  const _EventDetailSheet({required this.event, required this.focusedMonth});

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    } on CalendarEventDeleteFailedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarDeleteErrorMessage(e))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarDeleteErrorMessage(e))),
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
    final dateLabel = DateFormat("EEEE d 'de' MMMM", 'es').format(event.date);
    final formattedDate = dateLabel[0].toUpperCase() + dateLabel.substring(1);
    final media = MediaQuery.of(context);
    // Modal por encima de la nav: no reservar altura de la barra (hinchaba el sheet).
    final maxHeight = media.size.height * 0.62;
    final bottomPad = media.padding.bottom + 16;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detalle del evento',
                            style: AppTypography.displaySmall().copyWith(
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: AppTypography.bodyMedium(
                              color: AppColors.burgundy,
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.burgundy),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
                  children: [
                    _EventDetailCard(
                      event: event,
                      dateLabel: formattedDate,
                    ),
                    if (event.publisherHandle != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Publicado por ${event.publisherHandle}',
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (canManage) ...[
                      const SizedBox(height: 14),
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
                                side: const BorderSide(
                                  color: AppColors.accentRed,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailCard extends StatelessWidget {
  const _EventDetailCard({required this.event, required this.dateLabel});

  final CalendarEvent event;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final location = event.location?.trim().isNotEmpty == true
        ? event.location!.trim()
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: EventTypeIcon(
                type: event.type,
                size: 72,
                customIconUrl: event.customIconUrl,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: _TypePill(type: event.type)),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: AppTypography.displaySmall().copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _DetailRow(icon: Icons.calendar_month, text: dateLabel),
                if (event.time != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(icon: Icons.schedule, text: event.time!),
                ],
                if (location != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(icon: Icons.location_on, text: location),
                ],
              ],
            ),
          ),
          if (event.subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Descripción',
              style: AppTypography.labelSmall(
                color: AppColors.goldDark,
              ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              event.subtitle,
              style: AppTypography.bodyMedium().copyWith(
                fontSize: 14.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: AppTypography.labelSmall(
          color: AppColors.burgundy,
        ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
          ),
          child: Icon(icon, size: 17, color: AppColors.goldDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium().copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
