import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.item});

  final ProfileInfoItem item;

  static const _cardColor = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.burgundy.withValues(alpha: 0.85),
            ),
            child: Icon(item.icon, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: AppTypography.labelSmall(color: AppColors.goldLight),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: AppTypography.bodyLarge(color: AppColors.textOnDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
