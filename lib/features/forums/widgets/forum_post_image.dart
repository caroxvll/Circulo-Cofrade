import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import 'forum_post_image_viewer.dart';

/// Cartel o foto adjunta a una publicación oficial (vista previa en el hilo).
class ForumPostImage extends StatelessWidget {
  const ForumPostImage({
    super.key,
    required this.imageUrl,
    this.shareText,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.maxPreviewHeight = 420,
  });

  final String imageUrl;
  final String? shareText;
  final BorderRadius borderRadius;
  final double maxPreviewHeight;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: AppColors.backgroundElevated.withValues(alpha: 0.35),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showForumPostImageViewer(
          context,
          imageUrl: url,
          shareText: shareText,
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxPreviewHeight),
                child: CofradeoNetworkImage(
                  url: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  cacheSize: width.clamp(320.0, 1080.0),
                  placeholder: SizedBox(
                    height: 180,
                    child: _placeholder(
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  errorWidget: _placeholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_out_map,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ver completa',
                        style: AppTypography.labelSmall(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({Widget? child}) {
    return Container(
      height: 180,
      color: AppColors.backgroundElevated,
      alignment: Alignment.center,
      child: child ??
          Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textMuted.withValues(alpha: 0.7),
            size: 32,
          ),
    );
  }
}
