import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../topic_detail_typography.dart';
import '../utils/reply_reactions.dart';

Future<void> showHermandadBoardStatsSheet(
  BuildContext context, {
  required int viewCount,
  required int comunicadoCount,
  required Map<String, int> reactionBreakdown,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final totalReactions = totalReactionCount(reactionBreakdown);
      final sorted = sortedReactionCounts(reactionBreakdown);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Resumen del tablón',
                style: AppTypography.titleLarge(color: AppColors.burgundy),
              ),
              const SizedBox(height: 16),
              _SummaryRow(
                icon: Icons.visibility_outlined,
                label: 'Visitas al tablón',
                value: '$viewCount',
              ),
              _SummaryRow(
                icon: Icons.campaign_outlined,
                label: 'Comunicados publicados',
                value: '$comunicadoCount',
              ),
              _SummaryRow(
                icon: Icons.add_reaction_outlined,
                label: 'Reacciones totales',
                value: '$totalReactions',
              ),
              if (sorted.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Por tipo de reacción',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in sorted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reactionLabel(entry.key),
                            style: AppTypography.bodyMedium(),
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: TopicDetailTypography.meta(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.goldDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: AppTypography.bodyMedium()),
          ),
          Text(
            value,
            style: TopicDetailTypography.meta(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
