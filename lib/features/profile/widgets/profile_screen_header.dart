import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/calendar_quick_access_button.dart';
import '../profile_design.dart';

class ProfileScreenHeader extends StatelessWidget {
  const ProfileScreenHeader({
    super.key,
    this.menuButton,
  });

  final Widget? menuButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'PERFIL',
            style: ProfileDesign.screenTitle(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const CalendarQuickAccessButton(),
        if (menuButton != null) menuButton!,
      ],
    );
  }
}

class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: ProfileDesign.cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldPale.withValues(alpha: 0.45),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: AppColors.goldDark, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, style: ProfileDesign.sectionTitle()),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: ProfileDesign.meta().copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
