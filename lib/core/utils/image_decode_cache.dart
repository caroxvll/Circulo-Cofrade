import 'package:flutter/material.dart';

/// Acota el decode de assets al tamaño en pantalla (evita PNG/JPEG full-res).
abstract final class ImageDecodeCache {
  /// Píxeles físicos para un lado lógico.
  static int px(BuildContext context, double logical) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (logical * dpr).round().clamp(1, 4096);
  }

  /// Asset redimensionado al viewport (fondos full-bleed).
  static ImageProvider screenSizedAsset(
    BuildContext context,
    String assetPath,
  ) {
    final size = MediaQuery.sizeOf(context);
    return ResizeImage(
      AssetImage(assetPath),
      width: px(context, size.width),
      height: px(context, size.height),
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }

  /// Asset acotado a un lado lógico máximo (thumbs, logos, covers).
  static ImageProvider sizedAsset(
    BuildContext context,
    String assetPath, {
    required double logicalSide,
  }) {
    final cache = px(context, logicalSide);
    return ResizeImage(
      AssetImage(assetPath),
      width: cache,
      height: cache,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }
}
