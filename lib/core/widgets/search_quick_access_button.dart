import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// Acceso a Buscar desde cabeceras (ya no es tab del bottom nav).
class SearchQuickAccessButton extends StatelessWidget {
  const SearchQuickAccessButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.burgundy;

    return IconButton(
      onPressed: () => context.push('/buscar'),
      icon: const Icon(Icons.search),
      color: color,
      iconSize: 24,
      tooltip: 'Buscar',
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        overlayColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}
