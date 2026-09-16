import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../shared/models/calendar_event.dart';
import '../calendar_design_tokens.dart';
import 'calendar_event_image.dart';

class CalendarHeroCarousel extends StatefulWidget {
  const CalendarHeroCarousel({
    super.key,
    required this.events,
    required this.onEventTap,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  State<CalendarHeroCarousel> createState() => _CalendarHeroCarouselState();
}

class _CalendarHeroCarouselState extends State<CalendarHeroCarousel> {
  late final PageController _controller;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    final hasMultiple = widget.events.length > 1;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: CalendarDesign.heroAspectRatio,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.events.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final event = widget.events[index];
              return _HeroSlide(
                event: event,
                onTap: () => widget.onEventTap(event),
                showArrow: hasMultiple,
                onNext: hasMultiple
                    ? () {
                        final next = (_page + 1) % widget.events.length;
                        _controller.animateToPage(
                          next,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    : null,
              );
            },
          ),
        ),
        if (hasMultiple) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.events.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? AppColors.burgundy : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.event,
    required this.onTap,
    required this.showArrow,
    this.onNext,
  });

  final CalendarEvent event;
  final VoidCallback onTap;
  final bool showArrow;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMM', 'es')
        .format(event.date)
        .replaceAll('.', '')
        .toUpperCase();
    final location = event.location?.trim().isNotEmpty == true
        ? event.location!.trim()
        : event.subtitle;
    final hasCover = CalendarEventImage.hasDisplayableCover(event);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CalendarDesign.heroRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CalendarDesign.heroRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CalendarDesign.heroRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  CalendarEventImage(
                    event: event,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    showTypeFallback: false,
                  )
                else
                  const _HeroPatternBackground(),
                if (hasCover)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const [0.0, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TypeTag(label: event.type.cellLabel.toUpperCase()),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _DateBadge(day: event.date.day, month: monthLabel),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: AppTypography.displaySmall(
                                    color: AppColors.textOnDark,
                                  ).copyWith(
                                    fontSize: CalendarDesign.heroTitleSize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                _HeroMeta(
                                  icon: Icons.location_on_outlined,
                                  text: location,
                                ),
                                if (event.time != null) ...[
                                  const SizedBox(height: 2),
                                  _HeroMeta(
                                    icon: Icons.schedule_outlined,
                                    text: event.time!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (showArrow && onNext != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 2),
                              child: Material(
                                color: AppColors.surface,
                                shape: const CircleBorder(),
                                elevation: 0,
                                child: InkWell(
                                  onTap: onNext,
                                  customBorder: const CircleBorder(),
                                  child: SizedBox(
                                    width: CalendarDesign.heroArrowSize,
                                    height: CalendarDesign.heroArrowSize,
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.85),
                                      size: CalendarDesign.heroArrowIconSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fondo damasco del mockup cuando el evento no tiene portada propia.
class _HeroPatternBackground extends StatelessWidget {
  const _HeroPatternBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.loginBackground,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          cacheWidth: ImageDecodeCache.px(
            context,
            MediaQuery.sizeOf(context).width,
          ),
          gaplessPlayback: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.burgundyDark.withValues(alpha: 0.52),
                AppColors.burgundy.withValues(alpha: 0.78),
                AppColors.burgundyDark.withValues(alpha: 0.88),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall(color: AppColors.burgundyDark).copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1,
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.day, required this.month});

  final int day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CalendarDesign.heroBadgeWidth,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(CalendarDesign.heroBadgeRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$day',
            style: AppTypography.displaySmall(color: AppColors.textOnDark)
                .copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1),
          ),
          Text(
            month,
            style: AppTypography.labelSmall(color: AppColors.textOnDark)
                .copyWith(fontSize: 8.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: AppColors.textOnDark.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium(color: AppColors.textOnDark)
                .copyWith(
              fontSize: CalendarDesign.heroMetaSize,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
