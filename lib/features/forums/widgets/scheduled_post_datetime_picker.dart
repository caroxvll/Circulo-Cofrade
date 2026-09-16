import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../forum_topics_typography.dart';

class ScheduledPostDatetimePicker extends StatelessWidget {
  const ScheduledPostDatetimePicker({
    super.key,
    required this.scheduledAt,
    required this.onChanged,
  });

  final DateTime scheduledAt;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat("EEEE d 'de' MMMM", 'es').format(scheduledAt);
    final timeLabel = DateFormat('HH:mm', 'es').format(scheduledAt);

    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_rounded,
                color: AppColors.burgundy,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: ForumTopicsTypography.style(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Publicar '),
                      TextSpan(
                        text: '$dateLabel · $timeLabel',
                        style: ForumTopicsTypography.style(
                          color: AppColors.burgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
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

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
    );
    if (time == null) return;

    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}
