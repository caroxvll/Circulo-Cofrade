import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import 'sponsored_ad_card.dart';

/// Placeholder con la forma del anuncio mientras llega el sorteo / la imagen.
class SponsoredAdSkeleton extends StatelessWidget {
  const SponsoredAdSkeleton({
    super.key,
    this.style = SponsoredAdCardStyle.banner,
    this.compact = false,
  });

  final SponsoredAdCardStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      SponsoredAdCardStyle.forumsDocked => const _DockedSkeleton(),
      SponsoredAdCardStyle.event => _EventSkeleton(compact: compact),
      SponsoredAdCardStyle.banner => _BannerSkeleton(compact: compact),
    };
  }
}

class _DockedSkeleton extends StatelessWidget {
  const _DockedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navBarBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.gold.withValues(alpha: 0.12),
                  AppColors.gold.withValues(alpha: 0.55),
                  AppColors.gold.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
          const AspectRatio(
            aspectRatio: 4.35,
            child: CofradeoSkeletonBone(height: double.infinity, borderRadius: 0),
          ),
        ],
      ),
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 72.0 : 96.0;
    return CofradeoSkeletonBone(height: height, borderRadius: 14);
  }
}

class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 6),
          child: CofradeoSkeletonBone(width: 120, height: 10, borderRadius: 4),
        ),
        CofradeoSkeletonBone(
          height: compact ? 88.0 : 120.0,
          borderRadius: 18,
        ),
      ],
    );
  }
}
