import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'profile_fleur_divider.dart';

/// Empty state de la pestaña Temas: catedral + CTA.
class ProfileTopicsEmptyState extends StatelessWidget {
  const ProfileTopicsEmptyState({
    super.key,
    this.isOwnProfile = true,
  });

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              AppAssets.profileEmptyCathedral,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 18),
          const ProfileFleurDivider(),
          const SizedBox(height: 16),
          Text(
            isOwnProfile
                ? 'Aún no has publicado ningún tema'
                : 'Aún no hay temas publicados',
            style: AppTypography.displaySmall(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 18, height: 1.25),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isOwnProfile
                ? 'Comparte tus ideas, abre un debate o inicia '
                    'una conversación con la comunidad.'
                : 'Cuando publique en los foros, aparecerán aquí.',
            style: AppTypography.bodyMedium(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13.5, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (isOwnProfile) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/foros'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Crear tema',
                  style: AppTypography.titleLarge(color: Colors.white).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
