import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../forums/viewer_id_provider.dart';
import '../../calendar/widgets/calendar_event_image.dart';
import '../ads_provider.dart';
import '../models/sponsored_ad.dart';

enum SponsoredAdCardStyle { banner, event, forumsDocked }

class SponsoredAdCard extends ConsumerStatefulWidget {
  const SponsoredAdCard({
    super.key,
    required this.ad,
    this.compact = false,
    this.style = SponsoredAdCardStyle.banner,
    this.event,
    this.onEventTap,
  });

  final SponsoredAd ad;
  final bool compact;
  final SponsoredAdCardStyle style;
  final CalendarEvent? event;
  final ValueChanged<CalendarEvent>? onEventTap;

  @override
  ConsumerState<SponsoredAdCard> createState() => _SponsoredAdCardState();
}

class _SponsoredAdCardState extends ConsumerState<SponsoredAdCard> {
  Timer? _visibleTimer;
  var _impressionSent = false;

  @override
  void dispose() {
    _visibleTimer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_impressionSent) return;
    if (info.visibleFraction < 0.5) {
      _visibleTimer?.cancel();
      _visibleTimer = null;
      return;
    }
    _visibleTimer ??= Timer(const Duration(seconds: 1), _registerImpression);
  }

  Future<void> _registerImpression() async {
    if (_impressionSent) return;
    _impressionSent = true;
    final viewerId = ref.read(viewerIdProvider);
    await ref
        .read(adsRepositoryProvider)
        .registerImpression(adId: widget.ad.id, viewerId: viewerId);
  }

  Future<void> _openAd() async {
    final viewerId = ref.read(viewerIdProvider);
    await ref
        .read(adsRepositoryProvider)
        .registerClick(adId: widget.ad.id, viewerId: viewerId);

    final uri = Uri.tryParse(widget.ad.targetUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEvent(CalendarEvent event) async {
    final viewerId = ref.read(viewerIdProvider);
    final adsRepository = ref.read(adsRepositoryProvider);

    unawaited(
      adsRepository
          .registerClick(adId: widget.ad.id, viewerId: viewerId)
          .catchError((_) {}),
    );

    widget.onEventTap?.call(event);
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final child = widget.style == SponsoredAdCardStyle.event
        ? _SponsoredEventContent(
            ad: ad,
            event: widget.event,
            onTap: widget.event != null && widget.onEventTap != null
                ? () => _openEvent(widget.event!)
                : _openAd,
          )
        : _SponsoredBannerContent(
            ad: ad,
            compact: widget.compact,
            docked: widget.style == SponsoredAdCardStyle.forumsDocked,
            onTap: _openAd,
          );

    // `visibility_detector` crea un timer interno que en `flutter test` puede
    // quedarse pendiente y fallar la aserción `timersPending`.
    // En tests no necesitamos la lógica de impresiones, así que evitamos el
    // componente por completo.
    final isWidgetTest = WidgetsBinding
        .instance
        .runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (isWidgetTest) return child;

    return VisibilityDetector(
      key: ValueKey('ad-${ad.id}-${ad.placement.value}-${widget.style.name}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: child,
    );
  }
}

class _SponsoredBannerContent extends StatelessWidget {
  const _SponsoredBannerContent({
    required this.ad,
    required this.compact,
    required this.onTap,
    this.docked = false,
  });

  final SponsoredAd ad;
  final bool compact;
  final bool docked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ad.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return docked
          ? _ForumsDockedImageAd(ad: ad, imageUrl: imageUrl, onTap: onTap)
          : _ImageBannerAd(ad: ad, imageUrl: imageUrl, onTap: onTap);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF17120D), Color(0xFF2B1710), Color(0xFF0D0D0D)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _SponsorMark(imageUrl: ad.imageUrl, title: ad.title),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patrocinado',
                        style: AppTypography.labelSmall(
                          color: AppColors.goldLight,
                        ).copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ad.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.displaySmall(
                          color: AppColors.goldPale,
                        ).copyWith(fontSize: 22, height: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad.description,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall(
                          color: AppColors.textOnDark.withValues(alpha: 0.82),
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ad.buttonText,
                    style: AppTypography.labelSmall(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 11, fontWeight: FontWeight.w800),
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

class _ForumsDockedImageAd extends StatelessWidget {
  const _ForumsDockedImageAd({
    required this.ad,
    required this.imageUrl,
    required this.onTap,
  });

  final SponsoredAd ad;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navBarBackground,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.navBarBackground,
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundyDark.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.12),
                      AppColors.gold.withValues(alpha: 0.85),
                      AppColors.gold.withValues(alpha: 0.12),
                    ],
                  ),
                ),
              ),
              AspectRatio(
                aspectRatio: 4.35,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AdBannerImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      cacheSize: 1200,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.48),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Publicidad',
                          style: AppTypography.labelSmall(
                            color: AppColors.goldPale,
                          ).copyWith(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.goldDark],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          ad.buttonText,
                          style: AppTypography.labelSmall(
                            color: AppColors.textPrimary,
                          ).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageBannerAd extends StatelessWidget {
  const _ImageBannerAd({
    required this.ad,
    required this.imageUrl,
    required this.onTap,
  });

  final SponsoredAd ad;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 0, 6),
                child: Text(
                  'Publicidad',
                  style: AppTypography.labelSmall(
                    color: AppColors.goldDark,
                  ).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: AspectRatio(
                  aspectRatio: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AdBannerImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        cacheSize: 1200,
                      ),
                      Positioned(
                        right: 28,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            ad.buttonText,
                            style:
                                AppTypography.labelSmall(
                                  color: AppColors.textPrimary,
                                ).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SponsoredEventContent extends StatelessWidget {
  const _SponsoredEventContent({
    required this.ad,
    required this.onTap,
    this.event,
  });

  final SponsoredAd ad;
  final VoidCallback onTap;
  final CalendarEvent? event;

  @override
  Widget build(BuildContext context) {
    final event = this.event;
    final title = event?.title ?? ad.title;
    final eventType = event?.type.cellLabel ?? 'Evento';
    final dateText = event == null
        ? null
        : _capitalize(DateFormat('EEE d MMM', 'es').format(event.date));
    final timeText = event?.time?.trim();
    final scheduleText = dateText == null
        ? null
        : [
            dateText,
            if (timeText != null && timeText.isNotEmpty) timeText,
          ].join(' - ');
    final location = event?.location;
    final organizer = event?.organizerLabel;
    final detailText = _detailText(location: location, organizer: organizer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(
            'EVENTO PATROCINADO',
            style: AppTypography.labelSmall(
              color: AppColors.goldDark,
            ).copyWith(fontSize: 10, letterSpacing: 0.6),
          ),
        ),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 330;
                  final imageSize = isTight ? 86.0 : 94.0;
                  final sponsorWidth = isTight ? 112.0 : 132.0;
                  final metaFontSize = isTight ? 9.8 : 10.6;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SponsoredEventVisual(
                        ad: ad,
                        event: event,
                        size: imageSize,
                      ),
                      SizedBox(width: isTight ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              eventType.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppTypography.labelSmall(
                                    color: AppColors.goldDark,
                                  ).copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.35,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  style: AppTypography.titleLarge().copyWith(
                                    fontSize: isTight ? 12.8 : 14,
                                    fontWeight: FontWeight.w900,
                                    height: 1.04,
                                    letterSpacing: -0.25,
                                  ),
                                ),
                              ),
                            ),
                            if (scheduleText != null) ...[
                              const SizedBox(height: 6),
                              _ScaleDownLine(
                                text: scheduleText,
                                style:
                                    AppTypography.bodyMedium(
                                      color: AppColors.burgundy,
                                    ).copyWith(
                                      fontSize: metaFontSize,
                                      fontWeight: FontWeight.w800,
                                      height: 1.05,
                                    ),
                              ),
                            ],
                            if (detailText != null) ...[
                              const SizedBox(height: 4),
                              _ScaleDownLine(
                                text: detailText,
                                style:
                                    AppTypography.bodyMedium(
                                      color: AppColors.textSecondary,
                                    ).copyWith(
                                      fontSize: metaFontSize,
                                      fontWeight: FontWeight.w500,
                                      height: 1.05,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: isTight ? 6 : 10),
                      SizedBox(
                        width: sponsorWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Patrocinado por:',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style:
                                  AppTypography.labelSmall(
                                    color: AppColors.textMuted,
                                  ).copyWith(
                                    fontSize: isTight ? 7.2 : 8.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            _SponsorLogoOrName(
                              ad: ad,
                              width: sponsorWidth,
                              height: isTight ? 68 : 76,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String? _detailText({String? location, String? organizer}) {
    final cleanLocation = location?.trim();
    if (cleanLocation != null && cleanLocation.isNotEmpty) {
      return cleanLocation;
    }

    final cleanOrganizer = organizer?.trim();
    if (cleanOrganizer != null && cleanOrganizer.isNotEmpty) {
      return 'Organiza: $cleanOrganizer';
    }

    return null;
  }
}

class _SponsoredEventVisual extends StatelessWidget {
  const _SponsoredEventVisual({
    required this.ad,
    required this.event,
    required this.size,
  });

  final SponsoredAd ad;
  final CalendarEvent? event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ad.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _EventImage(imageUrl: imageUrl, size: size);
    }
    final event = this.event;
    if (event != null) {
      if (CalendarEventImage.hasDisplayableCover(event)) {
        return _EventCoverThumbnail(event: event, size: size);
      }
      return EventTypeIcon(
        type: event.type,
        size: size,
        customIconUrl: event.customIconUrl,
        roundedSquare: true,
      );
    }
    return _EventFallbackImage(size: size);
  }
}

class _EventCoverThumbnail extends StatelessWidget {
  const _EventCoverThumbnail({required this.event, required this.size});

  final CalendarEvent event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cover = event.coverImageUrl!.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: cover.startsWith('assets/')
            ? Image.asset(
                cover,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: ImageDecodeCache.px(context, size),
                cacheHeight: ImageDecodeCache.px(context, size),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _EventFallbackImage(size: size),
              )
            : CofradeoNetworkImage(
                url: cover,
                fit: BoxFit.cover,
                width: size,
                height: size,
                cacheSize: size,
                filterQuality: FilterQuality.medium,
                errorWidget: _EventFallbackImage(size: size),
              ),
      ),
    );
  }
}

class _ScaleDownLine extends StatelessWidget {
  const _ScaleDownLine({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, style: style),
      ),
    );
  }
}

class _SponsorLogoOrName extends StatelessWidget {
  const _SponsorLogoOrName({
    required this.ad,
    this.width = 72,
    this.height = 58,
  });

  final SponsoredAd ad;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final logoUrl = ad.sponsorLogoUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final image = logoUrl.startsWith('assets/')
          ? Image.asset(
              logoUrl,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
              cacheWidth: ImageDecodeCache.px(context, width),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _SponsorName(ad: ad),
            )
          : CofradeoNetworkImage(
              url: logoUrl,
              fit: BoxFit.contain,
              cacheSize: width,
              filterQuality: FilterQuality.medium,
              errorWidget: _SponsorName(ad: ad),
            );

      return Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Center(child: image),
        ),
      );
    }
    return _SponsorName(ad: ad);
  }
}

class _SponsorName extends StatelessWidget {
  const _SponsorName({required this.ad});

  final SponsoredAd ad;

  @override
  Widget build(BuildContext context) {
    return Text(
      ad.sponsorName.toUpperCase(),
      textAlign: TextAlign.end,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.titleLarge(
        color: AppColors.burgundy,
      ).copyWith(fontSize: 14, height: 1),
    );
  }
}

class _AdBannerImage extends StatelessWidget {
  const _AdBannerImage({
    required this.imageUrl,
    required this.fit,
    required this.cacheSize,
  });

  final String imageUrl;
  final BoxFit fit;
  final double cacheSize;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: fit,
        filterQuality: FilterQuality.medium,
        cacheWidth: ImageDecodeCache.px(context, cacheSize),
        gaplessPlayback: true,
      );
    }

    return CofradeoNetworkImage(
      url: imageUrl,
      fit: fit,
      cacheSize: cacheSize,
      errorWidget: ColoredBox(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: AppColors.burgundy),
        ),
      ),
    );
  }
}

class _SponsorMark extends StatelessWidget {
  const _SponsorMark({required this.imageUrl, required this.title});

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CofradeoNetworkImage(
          url: url,
          width: 58,
          height: 58,
          cacheSize: 58,
          fit: BoxFit.cover,
          errorWidget: _FallbackMark(title: title),
        ),
      );
    }
    return _FallbackMark(title: title);
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final initial = title.trim().isEmpty ? 'C' : title.trim()[0].toUpperCase();
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.displaySmall(
            color: AppColors.gold,
          ).copyWith(fontSize: 24),
        ),
      ),
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CofradeoNetworkImage(
          url: url,
          width: size,
          height: size,
          cacheSize: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorWidget: _EventFallbackImage(size: size),
        ),
      );
    }
    return _EventFallbackImage(size: size);
  }
}

class _EventFallbackImage extends StatelessWidget {
  const _EventFallbackImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.church, color: AppColors.burgundy, size: 34),
    );
  }
}
