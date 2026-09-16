import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/image_decode_cache.dart';
import '../../features/calendar/utils/holy_week_countdown.dart';
import 'countdown_banner_artboard.dart';

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
    final digits = CountdownBannerArtboard.digitsForDays(
      countdown.countdownDays!,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: CountdownBannerArtboard.designWidth /
            CountdownBannerArtboard.designHeight,
        child: Image.asset(
          AppAssets.countdownBanner,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: ImageDecodeCache.px(
            context,
            MediaQuery.sizeOf(context).width,
          ),
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame == null) {
              return ColoredBox(
                color: AppColors.surfaceAlt,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    for (var i = 0;
                        i < CountdownBannerArtboard.digitSlots.length;
                        i++)
                      _DigitSlot(
                        slot: CountdownBannerArtboard.digitSlots[i],
                        digit: digits[i],
                        bannerWidth: width,
                        bannerHeight: height,
                      ),
                  ],
                );
              },
            );
          },
          errorBuilder: (_, __, ___) =>
              _FallbackCardBanner(countdown: countdown, compact: true),
        ),
      ),
    );
  }
}

class _DigitSlot extends StatelessWidget {
  const _DigitSlot({
    required this.slot,
    required this.digit,
    required this.bannerWidth,
    required this.bannerHeight,
  });

  final Rect slot;
  final String digit;
  final double bannerWidth;
  final double bannerHeight;

  @override
  Widget build(BuildContext context) {
    final cx =
        bannerWidth * (slot.center.dx / CountdownBannerArtboard.designWidth);
    final cy =
        bannerHeight * (slot.center.dy / CountdownBannerArtboard.designHeight);
    final width =
        bannerWidth * (slot.width / CountdownBannerArtboard.designWidth);
    final height =
        bannerHeight * (slot.height / CountdownBannerArtboard.designHeight);
    final fontSize = height * 0.68;

    return Positioned(
      left: cx - width / 2,
      top: cy - height / 2,
      width: width,
      height: height,
      child: Center(
        child: Text(
          digit,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: GoogleFonts.cormorantGaramond(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.burgundyDark,
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
