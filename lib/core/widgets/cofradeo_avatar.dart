import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'cofradeo_network_image.dart';

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
      child: imageUrl != null && imageUrl!.trim().isNotEmpty
          ? CofradeoNetworkImage(
              url: imageUrl!,
              width: size,
              height: size,
              cacheSize: size,
              fit: BoxFit.cover,
              placeholder: Icon(
                icon ?? Icons.person,
                color: AppColors.gold,
                size: size * 0.5,
              ),
              errorWidget: Icon(
                icon ?? Icons.person,
                color: AppColors.gold,
                size: size * 0.5,
              ),
            )
          : Icon(
              icon ?? Icons.person,
              color: AppColors.gold,
              size: size * 0.5,
            ),
    );
  }
}
