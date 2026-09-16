import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../shared/models/forum.dart';
import 'forum_icons.dart';

/// Icono empaquetado en la app para cada foro (no editable desde admin).
String? forumPillarBundledAsset(String forumId) {
  return switch (forumId) {
    'foro-cofradiero' => AppAssets.forumCofradieroIcon,
    'pentagrama-cofrade' => AppAssets.forumPentagramaIcon,
    'martillo-trabajadera' => AppAssets.forumMartilloIcon,
    'hermandades' => AppAssets.forumHermandadesIcon,
    'noticias' => AppAssets.forumNoticiasIcon,
    _ => null,
  };
}

/// Los iconos de foro son siempre assets locales empaquetados.
String? forumPillarImageSource(ForumCategory forum) {
  return forumPillarBundledAsset(forum.id);
}

bool forumPillarImageIsAsset(String source) {
  return !source.startsWith('http://') && !source.startsWith('https://');
}

/// Medallón circular del foro con su JPG fijo empaquetado.
class ForumPillarIconImage extends StatelessWidget {
  const ForumPillarIconImage({
    super.key,
    required this.forum,
    this.size = 54,
    this.locked = false,
    this.borderRadius,
  });

  final ForumCategory forum;
  final double size;
  final bool locked;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isCircle = borderRadius == null;
    final fallbackIcon = forum.iconKey != null
        ? forumIconFromKey(forum.iconKey)
        : forum.icon;

    if (locked) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.25),
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : borderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Icon(
          Icons.lock_outline,
          color: AppColors.textMuted,
          size: size * 0.44,
        ),
      );
    }

    final source = forumPillarImageSource(forum);
    if (source == null) {
      return _materialFallback(
        fallbackIcon: fallbackIcon,
        isCircle: isCircle,
      );
    }

    return ClipRRect(
      borderRadius: isCircle
          ? BorderRadius.circular(size / 2)
          : borderRadius ?? BorderRadius.zero,
      child: Image.asset(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        cacheWidth: ImageDecodeCache.px(context, size),
        cacheHeight: ImageDecodeCache.px(context, size),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _materialFallback(
          fallbackIcon: fallbackIcon,
          isCircle: isCircle,
        ),
      ),
    );
  }

  Widget _materialFallback({
    required IconData fallbackIcon,
    required bool isCircle,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : borderRadius,
      ),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: AppColors.gold,
        size: size * 0.44,
      ),
    );
  }
}
