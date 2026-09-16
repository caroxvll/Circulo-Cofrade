import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../search_design.dart';

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.query,
  });

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: SearchDesign.cardDecoration(),
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
            child: const Icon(
              Icons.search_off_outlined,
              color: AppColors.goldDark,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin resultados',
            style: AppTypography.titleLarge(color: AppColors.burgundy),
          ),
          const SizedBox(height: 6),
          Text(
            'No encontramos nada para «$query». Prueba con un @handle, '
            'nombre de evento o palabra del foro.',
            style: SearchDesign.resultsSummary(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
