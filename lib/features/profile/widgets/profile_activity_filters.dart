import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../data/hidden_activity_store.dart';
import '../profile_design.dart';

class ProfileActivityFilters extends StatelessWidget {
  const ProfileActivityFilters({
    super.key,
    required this.filter,
    required this.onSelected,
  });

  final ActivityFeedFilter filter;
  final ValueChanged<ActivityFeedFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: ActivityFeedFilter.values.map((f) {
          final selected = filter == f;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(f),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.burgundy : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.burgundy.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    activityFilterLabel(f),
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textSecondary,
                    ).copyWith(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ProfileActivitySectionHeader extends StatelessWidget {
  const ProfileActivitySectionHeader({
    super.key,
    required this.count,
    required this.isOwnProfile,
  });

  final int count;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.goldPale.withValues(alpha: 0.7),
                AppColors.goldPale.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: const Icon(
            Icons.history_rounded,
            size: 15,
            color: AppColors.goldDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Tu actividad',
            style: ProfileDesign.sectionTitle(),
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              '$count',
              style: ProfileDesign.meta().copyWith(
                color: AppColors.burgundy,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        if (isOwnProfile) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Desliza una tarjeta para ocultarla de tu perfil',
            child: Icon(
              Icons.swipe_left_alt_rounded,
              size: 18,
              color: AppColors.textMuted.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }
}
