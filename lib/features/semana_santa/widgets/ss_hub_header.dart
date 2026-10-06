import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/topic_detail_typography.dart';

/// Cabecera compacta del hub SS (sin foto hero).
class SemanaSantaHubSummaryCard extends StatelessWidget {
  const SemanaSantaHubSummaryCard({
    super.key,
    required this.liveUpdateCount,
    required this.onPublish,
    this.liveOpen = true,
    this.canInform = false,
    this.jornadaLabel,
  });

  final int liveUpdateCount;
  final VoidCallback onPublish;
  final bool liveOpen;
  final bool canInform;
  final String? jornadaLabel;

  @override
  Widget build(BuildContext context) {
    final avisosLabel = liveUpdateCount == 1
        ? '1 aviso en directo'
        : '$liveUpdateCount avisos en directo';

    return Material(
      color: AppColors.surface,
      elevation: 1.5,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.burgundy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: AppColors.burgundy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoy en la calle',
                      style: AppTypography.displaySmall(
                        color: AppColors.burgundy,
                      ).copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      liveOpen
                          ? (canInform
                              ? avisosLabel
                              : '$avisosLabel · reacciona y comenta')
                          : (jornadaLabel != null
                              ? 'Cerrado · $jornadaLabel'
                              : 'El en directo está cerrado'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TopicDetailTypography.meta(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (liveOpen && canInform) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onPublish,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: Text(
                    '+ Informar',
                    style: TopicDetailTypography.body(
                      color: Colors.white,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
