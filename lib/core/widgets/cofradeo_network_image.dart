import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Imagen remota con caché en disco/memoria y decode acotado al tamaño en pantalla.
class CofradeoNetworkImage extends StatelessWidget {
  const CofradeoNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.cacheSize,
    this.filterQuality = FilterQuality.low,
    this.color,
    this.colorBlendMode,
    this.borderRadius,
    this.errorWidget,
    this.placeholder,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  /// Lado lógico máximo (px) para memoria/disco. Si null, se infiere de [width]/[height].
  final double? cacheSize;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final logical = cacheSize ?? width ?? height;
    final cachePx = logical != null ? (logical * pixelRatio).round() : null;
    final memCache = _resolveMemCache(cachePx, width, height);

    Widget image = CachedNetworkImage(
      imageUrl: trimmed,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      filterQuality: filterQuality,
      color: color,
      colorBlendMode: colorBlendMode,
      memCacheWidth: memCache.$1,
      memCacheHeight: memCache.$2,
      maxWidthDiskCache: memCache.$1 != null ? memCache.$1! * 2 : null,
      maxHeightDiskCache: memCache.$2 != null ? memCache.$2! * 2 : null,
      // Sin fade: evita parpadeo en scroll/push cuando la imagen ya está en caché.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) =>
          placeholder ?? _defaultPlaceholder(logical),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          ColoredBox(
            color: AppColors.backgroundElevated,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted.withValues(alpha: 0.7),
                size: (logical ?? 24) * 0.45,
              ),
            ),
          ),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  /// Solo acota un lado del decode para no deformar la proporción original.
  static (int?, int?) _resolveMemCache(
    int? cachePx,
    double? width,
    double? height,
  ) {
    if (cachePx == null) return (null, null);
    if (width != null && height != null) {
      if (width >= height) return (cachePx, null);
      return (null, cachePx);
    }
    if (width != null) return (cachePx, null);
    if (height != null) return (null, cachePx);
    return (cachePx, null);
  }

  /// Placeholder estable (sin spinner): la UI no “salta” al llegar la imagen.
  static Widget _defaultPlaceholder(double? _) {
    return const ColoredBox(
      color: AppColors.backgroundElevated,
      child: SizedBox.expand(),
    );
  }
}
