import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';

/// Puerta de entrada: login o registro (solo usuarios sin sesión).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burgundyDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final logoWidth = (constraints.maxWidth * 0.88).clamp(310.0, 430.0);
          final buttonWidth = (constraints.maxWidth * 0.78).clamp(260.0, 320.0);
          final buttonHeight = (constraints.maxHeight * 0.062).clamp(48.0, 54.0);
          final buttonTextStyle = AppTypography.displaySmall().copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          );
          final bgCache = ImageDecodeCache.px(context, constraints.maxWidth);
          final logoCache = ImageDecodeCache.px(context, logoWidth);

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                AppAssets.loginBackground,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                cacheWidth: bgCache,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF5A101A)),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                  child: Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * 0.18),
                      Image.asset(
                        AppAssets.logoLogin,
                        width: logoWidth,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: logoCache,
                        gaplessPlayback: true,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: FilledButton(
                          onPressed: () => context.push('/login'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF2A0710),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Iniciar sesión',
                            style: buttonTextStyle.copyWith(
                              color: const Color(0xFF2A0710),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: buttonWidth,
                        height: buttonHeight,
                        child: OutlinedButton(
                          onPressed: () => context.push('/registro'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            side: const BorderSide(
                              color: AppColors.gold,
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Crear cuenta',
                            style: buttonTextStyle.copyWith(
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
