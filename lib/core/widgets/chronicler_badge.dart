import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'cofradeo_badge.dart';

class ChroniclerIcon extends StatelessWidget {
  const ChroniclerIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cronista de Cofradeo',
      child: Icon(Icons.auto_stories_rounded, size: size, color: AppColors.goldDark),
    );
  }
}

class ChroniclerBadge extends StatelessWidget {
  const ChroniclerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const CofradeoBadge(
      label: 'Cronista',
      icon: Icons.auto_stories_rounded,
    );
  }
}
