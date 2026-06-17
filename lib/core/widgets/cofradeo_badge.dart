import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum CofradeoBadgeStyle { active, resolved }

class CofradeoBadge extends StatelessWidget {
  const CofradeoBadge({
    super.key,
    required this.label,
    this.style = CofradeoBadgeStyle.active,
    this.icon,
  });

  final String label;
  final CofradeoBadgeStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.accentRed),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelSmall(color: AppColors.textOnDark)
                .copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
