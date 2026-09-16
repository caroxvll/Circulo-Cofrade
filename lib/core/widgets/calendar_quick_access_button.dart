import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class CalendarQuickAccessButton extends StatelessWidget {
  const CalendarQuickAccessButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.burgundy;

    return IconButton(
      onPressed: () => context.go('/calendario'),
      icon: const Icon(Icons.calendar_month_outlined),
      color: color,
      iconSize: 24,
      tooltip: 'Calendario',
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        overlayColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}