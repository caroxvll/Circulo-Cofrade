import 'package:flutter/material.dart';

/// [Image.asset] con fade-in al terminar el decode (evita el “pop” brusco).
///
/// Si el frame ya estaba en caché (`wasSynchronouslyLoaded`), se muestra al instante.
class CofradeoAssetImage extends StatelessWidget {
  const CofradeoAssetImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.medium,
    this.gaplessPlayback = true,
    this.fadeDuration = const Duration(milliseconds: 280),
    this.color,
    this.colorBlendMode,
    this.errorBuilder,
  });

  final String assetPath;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final Duration fadeDuration;
  final Color? color;
  final BlendMode? colorBlendMode;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: filterQuality,
      gaplessPlayback: gaplessPlayback,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: errorBuilder,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || fadeDuration == Duration.zero) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: fadeDuration,
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
    );
  }
}
