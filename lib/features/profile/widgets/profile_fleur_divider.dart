import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Ornamento dorado tipo flor de lis entre identidad y stats.
class ProfileFleurDivider extends StatelessWidget {
  const ProfileFleurDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '⚜',
              style: TextStyle(
                fontSize: 15,
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.88),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
