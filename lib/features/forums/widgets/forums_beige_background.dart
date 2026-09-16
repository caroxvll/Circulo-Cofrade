import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_decode_cache.dart';

/// Textura beige compartida por Foros, temas de foro y otras pantallas.
class ForumsBeigeBackground extends StatelessWidget {
  const ForumsBeigeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: DecorationImage(
          image: ImageDecodeCache.screenSizedAsset(
            context,
            AppAssets.forumsBeigeBackground,
          ),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

/// DecorationImage beige acotada al viewport (para pantallas que envuelven con DecoratedBox).
DecorationImage forumsBeigeDecorationImage(BuildContext context) {
  return DecorationImage(
    image: ImageDecodeCache.screenSizedAsset(
      context,
      AppAssets.forumsBeigeBackground,
    ),
    fit: BoxFit.cover,
    alignment: Alignment.topCenter,
    filterQuality: FilterQuality.low,
  );
}
