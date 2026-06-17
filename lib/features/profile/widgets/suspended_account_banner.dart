import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class SuspendedAccountBanner extends StatelessWidget {
  const SuspendedAccountBanner({
    super.key,
    this.reason,
    this.compact = false,
  });

  final String? reason;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.burgundy.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.block_outlined,
            size: compact ? 18 : 20,
            color: AppColors.burgundy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta suspendida',
                  style: AppTypography.titleLarge().copyWith(
                    fontSize: compact ? 14 : 15,
                    color: AppColors.burgundy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason?.trim().isNotEmpty == true
                      ? reason!.trim()
                      : 'No puedes publicar, responder ni dar me gusta hasta que la Junta reactive la cuenta.',
                  style: AppTypography.bodyMedium().copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
