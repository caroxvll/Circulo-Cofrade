import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class CofradeoErrorPanel extends StatelessWidget {
  const CofradeoErrorPanel({
    super.key,
    this.message = 'No se pudo cargar el contenido.',
    this.subtitle,
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
  });

  final String message;
  final String? subtitle;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTypography.bodyLarge().copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
