import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../topic_detail_typography.dart';

/// Acceso rápido a borradores y publicaciones programadas del tablón.
class HermandadPendingPostsBanner extends StatelessWidget {
  const HermandadPendingPostsBanner({
    super.key,
    required this.draftCount,
    required this.scheduledCount,
  });

  final int draftCount;
  final int scheduledCount;

  int get _total => draftCount + scheduledCount;

  @override
  Widget build(BuildContext context) {
    if (_total <= 0) return const SizedBox.shrink();

    final parts = <String>[];
    if (draftCount > 0) {
      parts.add(draftCount == 1 ? '1 borrador' : '$draftCount borradores');
    }
    if (scheduledCount > 0) {
      parts.add(
        scheduledCount == 1
            ? '1 programada'
            : '$scheduledCount programadas',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.goldPale.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push('/perfil/publicaciones-programadas'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: AppColors.goldDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pendientes de publicar',
                        style: TopicDetailTypography.meta(
                          color: AppColors.burgundy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parts.join(' · '),
                        style: TopicDetailTypography.meta(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
