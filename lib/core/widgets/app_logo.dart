import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// Logo de Círculo Cofrade reutilizable en toda la app.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 120,
    this.useIconVariant = false,
    this.forLogin = false,
  });

  final double size;
  final bool useIconVariant;
  /// Variante con texto completo; solo para la pantalla de login.
  final bool forLogin;

  @override
  Widget build(BuildContext context) {
    if (forLogin) {
      return Image.asset(
        AppAssets.logoLogin,
        width: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _FallbackLogo(size: size);
        },
      );
    }

    final asset = useIconVariant ? AppAssets.logoIcon : AppAssets.logo;

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _FallbackLogo(size: size);
      },
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4A148C),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2),
      ),
      child: Text(
        'CC',
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFD4AF37),
        ),
      ),
    );
  }
}
