import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';

class ScheduledPostDatetimePicker extends StatelessWidget {
  const ScheduledPostDatetimePicker({
    super.key,
    required this.scheduledAt,
    required this.onChanged,
    this.actionLabel = 'Publicar',
  });

  final DateTime scheduledAt;
  final ValueChanged<DateTime> onChanged;

  /// «Publicar» cuando sale el comunicado. «El acto» cuando es la cita del calendario.
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat("EEEE d 'de' MMMM", 'es').format(scheduledAt);
    final timeLabel = DateFormat('HH:mm', 'es').format(scheduledAt);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              color: AppColors.burgundy,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _pick(context),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: RichText(
                    text: TextSpan(
                      style: ForumTopicsTypography.style(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(text: '$actionLabel '),
                        TextSpan(
                          text: dateLabel,
                          style: ForumTopicsTypography.style(
                            color: AppColors.burgundy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                onTap: () => _pickTime(context),
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    timeLabel,
                    style: ForumTopicsTypography.style(
                      color: AppColors.burgundy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (date == null || !context.mounted) return;

    onChanged(
      DateTime(
        date.year,
        date.month,
        date.day,
        scheduledAt.hour,
        scheduledAt.minute,
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
    );
    if (time == null) return;

    onChanged(
      DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
        time.hour,
        time.minute,
      ),
    );
  }
}
