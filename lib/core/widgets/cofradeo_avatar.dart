import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'cofradeo_network_image.dart';
import 'cofradeo_skeleton.dart';

class CofradeoAvatar extends StatelessWidget {
  const CofradeoAvatar({
    super.key,
    this.imageUrl,
    this.icon,
    this.size = 48,
    this.backgroundColor,
  });

  final String? imageUrl;
  final IconData? icon;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;
    final fallbackIcon = Icon(
      icon ?? Icons.person,
      color: AppColors.gold,
      size: size * 0.5,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? AppColors.burgundy,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? CofradeoNetworkImage(
              url: url,
              width: size,
              height: size,
              cacheSize: size,
              fit: BoxFit.cover,
              // Skeleton suave: evita el salto icono → foto en listados.
              placeholder: CofradeoSkeletonBone(
                width: size,
                height: size,
                borderRadius: size / 2,
              ),
              errorWidget: fallbackIcon,
            )
          : fallbackIcon,
    );
  }
}
