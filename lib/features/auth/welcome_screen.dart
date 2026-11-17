import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import 'auth_layout.dart';

/// Puerta de entrada: login o registro (solo usuarios sin sesión).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Calienta fondo/logo para que login/registro no “parpadeen” al entrar.
    precacheImage(const AssetImage(AppAssets.loginBackground), context);
    precacheImage(const AssetImage(AppAssets.logoLogin), context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burgundyDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            cacheWidth: ImageDecodeCache.px(
              context,
              MediaQuery.sizeOf(context).width,
            ),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF5A101A)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metrics = AuthLayoutMetrics.of(context, constraints);
                final logoWidth =
                    (metrics.width * (metrics.tight ? 0.62 : 0.74)).clamp(
                      metrics.tight ? 160.0 : 200.0,
                      360.0,
                    );
                final logoHeight =
                    (metrics.height < 640
                        ? 150.0
                        : metrics.height < 720
                        ? 190.0
                        : metrics.height < 820
                        ? 240.0
                        : metrics.height < 960
                        ? 280.0
                        : 320.0) /
                    (metrics.textScale > 1.2 ? 1.25 : 1);
                final buttonText = AppTypography.displaySmall().copyWith(
                  fontSize: metrics.tight ? 17 : (metrics.compact ? 19 : 21),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                );
                final topPad = metrics.tight ? 8.0 : 16.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    metrics.side,
                    topPad,
                    metrics.side,
                    metrics.bottomPad,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (metrics.height - topPad - metrics.bottomPad)
                          .clamp(0.0, double.infinity),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Center(
                          child: AuthBrandLogo(
                            width: logoWidth,
                            height: logoHeight,
                            zoom: 1.3,
                          ),
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: metrics.contentWidth.clamp(0.0, 360.0),
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: metrics.buttonHeight,
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
                                      style: buttonText.copyWith(
                                        color: const Color(0xFF2A0710),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: metrics.tight ? 10 : 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: metrics.buttonHeight,
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
                                      style: buttonText.copyWith(
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
