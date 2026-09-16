import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'cofradeo_badge.dart';

class VerifiedAccountIcon extends StatelessWidget {
  const VerifiedAccountIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cuenta verificada por Cofradeo',
      child: Icon(Icons.verified, size: size, color: AppColors.burgundy),
    );
  }
}

class VerifiedAccountBadge extends StatelessWidget {
  const VerifiedAccountBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const CofradeoBadge(
      label: 'Cuenta verificada',
      icon: Icons.verified,
    );
  }
}
