import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class EmailVerificationBanner extends StatelessWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 20,
            color: AppColors.goldDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirma tu email',
                  style: AppTypography.titleLarge().copyWith(
                    fontSize: 15,
                    color: AppColors.goldDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verifica tu cuenta para publicar, responder y seguir.',
                  style: AppTypography.bodyMedium().copyWith(fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/verificar-email'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Verificar ahora',
                    style: AppTypography.bodyMedium(color: AppColors.burgundy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
