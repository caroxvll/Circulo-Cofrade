import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';

/// Pantalla de arranque mientras Supabase restaura la sesión guardada.
class AuthSplashScreen extends StatelessWidget {
  const AuthSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mismo tono que bienvenida/login para que el fade auth no “corte” de color.
    return const Scaffold(
      backgroundColor: AppColors.burgundyDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 220, forLogin: true),
            SizedBox(height: 28),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
