import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../shared/models/forum.dart';

/// Portada lateral de la tarjeta destacada (recorte sobre el damasco).
class ForumPillarCover {
  ForumPillarCover({
    this.asset,
    this.networkUrl,
    this.alignment = Alignment.center,
    this.overlay = AppColorsOverlay.none,
    this.lightTreatment = false,
  });

  final String? asset;
  final String? networkUrl;
  final Alignment alignment;
  final Color overlay;

  /// Menos tinte y viñeta cuando hay foto propia del foro.
  final bool lightTreatment;

  bool get isNetwork => networkUrl != null && networkUrl!.trim().isNotEmpty;

  String get fallbackAsset => asset ?? AppAssets.loginBackground;
}

/// Tinte suave sobre la foto para diferenciar foros sin assets propios.
abstract final class AppColorsOverlay {
  static const none = Color(0x00000000);
  static const warm = Color(0x334A1020);
  static const cool = Color(0x33101830);
  static const deep = Color(0x40201010);
}

ForumPillarCover forumPillarCover(ForumCategory forum) {
  // Noticias: portada editorial local (evita URL remota con bordes/recorte feo).
  if (forum.id == 'noticias') {
    return ForumPillarCover(
      asset: AppAssets.noticiasCover,
      alignment: const Alignment(0.28, -0.08),
      lightTreatment: true,
    );
  }

  final remote = forum.coverImageUrl?.trim();
  if (remote != null && remote.isNotEmpty) {
    return ForumPillarCover(
      networkUrl: remote,
      alignment: Alignment.center,
      lightTreatment: true,
    );
  }

  return switch (forum.id) {
    'foro-cofradiero' => ForumPillarCover(
      asset: AppAssets.forumCofradieroCover,
      alignment: Alignment.center,
      lightTreatment: true,
    ),
    'pentagrama-cofrade' => ForumPillarCover(
      asset: AppAssets.forumPentagramaCover,
      alignment: Alignment.center,
      lightTreatment: true,
    ),
    'martillo-trabajadera' => ForumPillarCover(
      asset: AppAssets.forumMartilloCover,
      alignment: Alignment.center,
      lightTreatment: true,
    ),
    'hermandades' => ForumPillarCover(
      asset: AppAssets.forumHermandadesCover,
      alignment: Alignment.center,
      lightTreatment: true,
    ),
    _ => ForumPillarCover(asset: AppAssets.loginBackground),
  };
}

ImageProvider forumPillarCoverImageProvider(
  BuildContext context,
  ForumPillarCover cover, {
  double logicalSide = 320,
}) {
  if (cover.isNetwork) {
    return ResizeImage(
      NetworkImage(cover.networkUrl!),
      width: ImageDecodeCache.px(context, logicalSide),
      height: ImageDecodeCache.px(context, logicalSide),
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }
  return ImageDecodeCache.sizedAsset(
    context,
    cover.fallbackAsset,
    logicalSide: logicalSide,
  );
}

class ForumPillarCoverImage extends StatelessWidget {
  const ForumPillarCoverImage({
    super.key,
    required this.cover,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.color,
    this.colorBlendMode,
    this.width,
    this.height,
    this.cacheSize,
  });

  final ForumPillarCover cover;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Color? color;
  final BlendMode? colorBlendMode;
  final double? width;
  final double? height;

  /// Lado lógico máximo para decode/caché. Si null, se infiere del layout.
  final double? cacheSize;

  @override
  Widget build(BuildContext context) {
    final resolvedCacheSize = cacheSize ??
        width ??
        height ??
        MediaQuery.sizeOf(context).width.clamp(160.0, 640.0);
    final cachePx = ImageDecodeCache.px(context, resolvedCacheSize);

    if (cover.isNetwork) {
      // Placeholder sólido: no decodificar otro asset grande mientras llega la red.
      final solidPlaceholder = ColoredBox(
        color: AppColors.backgroundElevated,
        child: SizedBox(width: width, height: height),
      );
      return CofradeoNetworkImage(
        url: cover.networkUrl!,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheSize: resolvedCacheSize,
        filterQuality: filterQuality,
        color: color,
        colorBlendMode: colorBlendMode,
        placeholder: solidPlaceholder,
        errorWidget: solidPlaceholder,
      );
    }

    return Image.asset(
      cover.fallbackAsset,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      filterQuality: filterQuality,
      color: color,
      colorBlendMode: colorBlendMode,
      cacheWidth: cachePx,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Image.asset(
        AppAssets.loginBackground,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        filterQuality: FilterQuality.low,
        color: color,
        colorBlendMode: colorBlendMode,
        cacheWidth: cachePx,
      ),
    );
  }
}
