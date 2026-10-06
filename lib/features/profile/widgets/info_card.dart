import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_profile.dart';
import '../profile_design.dart';

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.item,
    this.compact = false,
  });

  final ProfileInfoItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: ProfileDesign.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(item.icon, color: AppColors.burgundy, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.label,
                    style: ProfileDesign.meta().copyWith(fontSize: 10.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.value,
              style: ProfileDesign.sectionTitle().copyWith(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

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
