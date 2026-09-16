import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_profile.dart';
import '../profile_design.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.item});

  final ProfileInfoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ProfileDesign.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldPale.withValues(alpha: 0.5),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(item.icon, color: AppColors.burgundy, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: ProfileDesign.meta()),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: ProfileDesign.sectionTitle().copyWith(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
