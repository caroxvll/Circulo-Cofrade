import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/image_decode_cache.dart';
import '../../features/calendar/utils/holy_week_countdown.dart';
import 'countdown_banner_artboard.dart';
import 'cofradeo_skeleton.dart';

enum CofradeCountdownBannerStyle { card, compact }

class CofradeCountdownBanner extends StatelessWidget {
  const CofradeCountdownBanner({
    super.key,
    required this.countdown,
    this.style = CofradeCountdownBannerStyle.card,
  });

  final CofradeCountdown countdown;
  final CofradeCountdownBannerStyle style;

  @override
  Widget build(BuildContext context) {
    if (style == CofradeCountdownBannerStyle.compact) {
      return _CompactLine(countdown: countdown);
    }
    if (countdown.usesArtworkBanner) {
      return _ArtworkBanner(countdown: countdown);
    }
    return _FallbackCardBanner(countdown: countdown);
  }
}

class _ArtworkBanner extends StatelessWidget {
  const _ArtworkBanner({required this.countdown});

  final CofradeCountdown countdown;

  @override
  Widget build(BuildContext context) {
    final daysLabel = CountdownBannerArtboard.labelForDays(
      countdown.countdownDays!,
    );

    // Stack fuera del Image: el RenderImage recorta overlays del frameBuilder.
    return AspectRatio(
      aspectRatio: CountdownBannerArtboard.designWidth /
          CountdownBannerArtboard.designHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                AppAssets.countdownBanner,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                cacheWidth: ImageDecodeCache.px(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null) {
                    return const ColoredBox(
                      color: AppColors.surfaceAlt,
                      child: SizedBox.expand(
                        child: CofradeoSkeletonBone(
                          height: double.infinity,
                          borderRadius: 0,
                        ),
                      ),
                    );
                  }
                  return child;
                },
                errorBuilder: (_, __, ___) =>
                    _FallbackCardBanner(countdown: countdown, compact: true),
              ),
              _DaysSlot(
                slot: CountdownBannerArtboard.daysSlot,
                label: daysLabel,
                bannerWidth: constraints.maxWidth,
                bannerHeight: constraints.maxHeight,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DaysSlot extends StatelessWidget {
  const _DaysSlot({
    required this.slot,
    required this.label,
    required this.bannerWidth,
    required this.bannerHeight,
  });

  final Rect slot;
  final String label;
  final double bannerWidth;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    final left =
        bannerWidth * (slot.left / CountdownBannerArtboard.designWidth);
    final top =
        bannerHeight * (slot.top / CountdownBannerArtboard.designHeight);
    final width =
        bannerWidth * (slot.width / CountdownBannerArtboard.designWidth);
    final height =
        bannerHeight * (slot.height / CountdownBannerArtboard.designHeight);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          softWrap: false,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 72,
            fontWeight: FontWeight.w700,
            color: AppColors.burgundy,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _FallbackCardBanner extends StatelessWidget {
  const _FallbackCardBanner({
    required this.countdown,
    this.compact = false,
  });

  final CofradeCountdown countdown;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final subtitle = countdown.subtitle;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.burgundy.withValues(alpha: 0.92),
            AppColors.burgundyDark.withValues(alpha: 0.96),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.burgundy.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 6 : 12,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _iconFor(countdown.milestone),
                color: AppColors.gold,
                size: compact ? 20 : 28,
              ),
              SizedBox(width: compact ? 8 : 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    countdown.headline,
                    style: AppTypography.titleLarge(
                      color: AppColors.textOnDark,
                    ).copyWith(
                      fontSize: compact ? 13 : 16,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium(
                        color: Colors.white.withValues(alpha: 0.88),
                      ).copyWith(
                        fontSize: compact ? 11 : 13,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({required this.countdown});

  final CofradeCountdown countdown;

  @override
  Widget build(BuildContext context) {
    final text = countdown.subtitle == null
        ? countdown.headline
        : '${countdown.headline} ${countdown.subtitle!}';

    return Row(
      children: [
        Icon(
          _iconFor(countdown.milestone),
          size: 16,
          color: AppColors.gold.withValues(alpha: 0.95),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(CofradeCountdownMilestone milestone) {
  return switch (milestone) {
    CofradeCountdownMilestone.palmSunday => Icons.eco_outlined,
    CofradeCountdownMilestone.holyWeek => Icons.church_outlined,
    CofradeCountdownMilestone.easter => Icons.wb_sunny_outlined,
  };
}
