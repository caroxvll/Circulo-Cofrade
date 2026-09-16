import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../ads_provider.dart';
import '../models/sponsored_ad.dart';
import 'sponsored_ad_card.dart';

/// Hueco de patrocinio remoto por placement (Supabase). Sin anuncio → no ocupa espacio.
class SponsoredPlacementSlot extends ConsumerWidget {
  const SponsoredPlacementSlot({
    super.key,
    required this.placement,
    this.forumId,
    this.topicId,
    this.style = SponsoredAdCardStyle.banner,
    this.compact = false,
    this.sectionLabel,
    this.padding,
    this.event,
    this.linkEventPool,
    this.onEventTap,
  });

  final AdPlacement placement;
  final String? forumId;
  final String? topicId;
  final SponsoredAdCardStyle style;
  final bool compact;
  final String? sectionLabel;
  final EdgeInsetsGeometry? padding;
  final CalendarEvent? event;
  final List<CalendarEvent>? linkEventPool;
  final ValueChanged<CalendarEvent>? onEventTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAsync = ref.watch(
      adForPlacementProvider(
        AdPlacementQuery(
          placement: placement,
          forumId: forumId,
          topicId: topicId,
        ),
      ),
    );

    return adAsync.when(
      data: (ad) {
        if (ad == null) return const SizedBox.shrink();

        final linkedEvent =
            event ??
            (linkEventPool == null
                ? null
                : sponsoredLinkedEvent(ad, linkEventPool!));

        final card = SponsoredAdCard(
          ad: ad,
          style: style,
          compact: compact,
          event: linkedEvent,
          onEventTap: onEventTap,
        );

        final content = sectionLabel == null
            ? card
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionLabel!,
                    style: AppTypography.labelSmall(
                      color: AppColors.goldDark,
                    ).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  card,
                ],
              );

        if (padding == null) return content;
        return Padding(padding: padding!, child: content);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Resuelve un evento vinculado al anuncio dentro de una lista ya cargada.
CalendarEvent? sponsoredLinkedEvent(
  SponsoredAd ad,
  List<CalendarEvent> events,
) {
  final id = ad.calendarEventId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final event in events) {
    if (event.id == id) return event;
  }
  return null;
}
