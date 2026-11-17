import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../utils/image_decode_cache.dart';

/// Logo de Círculo Cofrade reutilizable en toda la app.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 120,
    this.useIconVariant = false,
    this.forLogin = false,
    this.circular = false,
  });

  final double size;
  final bool useIconVariant;
  /// Variante con texto completo; solo para la pantalla de login.
  final bool forLogin;
  /// Recorte circular (avatar en feed / cabeceras).
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final cache = ImageDecodeCache.px(context, size);
    if (forLogin) {
      return Image.asset(
        AppAssets.logoLogin,
        width: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        cacheWidth: cache,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return _FallbackLogo(size: size);
        },
      );
    }

    final asset = useIconVariant ? AppAssets.logoIcon : AppAssets.logo;

    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: circular ? BoxFit.cover : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheWidth: cache,
      cacheHeight: cache,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return _FallbackLogo(size: size);
      },
    );

    if (!circular) return image;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: image),
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
