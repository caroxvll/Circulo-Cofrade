import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../search_design.dart';

class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.count,
  });

  final IconData icon;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.goldPale.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(icon, size: 15, color: AppColors.goldDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: SearchDesign.sectionTitle()),
        ),
        if (count != null && count! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              '$count',
              style: SearchDesign.sectionMeta().copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.burgundy,
              ),
            ),
          ),
      ],
    );
  }
}
