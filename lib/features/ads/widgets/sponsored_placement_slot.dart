import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/calendar_event.dart';
import '../ads_provider.dart';
import '../models/sponsored_ad.dart';
import 'sponsored_ad_card.dart';
import 'sponsored_ad_skeleton.dart';

/// Hueco de patrocinio remoto por placement (Supabase).
///
/// - Carga: skeleton con la forma del anuncio (no hueco vacío).
/// - Aparición / cambio de anuncio: crossfade suave.
/// - Sin anuncio: colapsa la altura sin salto brusco.
class SponsoredPlacementSlot extends ConsumerStatefulWidget {
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
    this.refreshOnMount = false,
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

  /// Al montar, pide un sorteo nuevo (barras del shell al volver a la pestaña).
  final bool refreshOnMount;

  @override
  ConsumerState<SponsoredPlacementSlot> createState() =>
      _SponsoredPlacementSlotState();
}

class _SponsoredPlacementSlotState extends ConsumerState<SponsoredPlacementSlot> {
  AdPlacementQuery get _query => AdPlacementQuery(
        placement: widget.placement,
        forumId: widget.forumId,
        topicId: widget.topicId,
      );

  @override
  void initState() {
    super.initState();
    if (!widget.refreshOnMount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adForPlacementProvider(_query));
    });
  }

  @override
  Widget build(BuildContext context) {
    final adAsync = ref.watch(adForPlacementProvider(_query));

    return SponsoredAdAsyncReveal(
      adAsync: adAsync,
      style: widget.style,
      compact: widget.compact,
      sectionLabel: widget.sectionLabel,
      padding: widget.padding,
      event: widget.event,
      linkEventPool: widget.linkEventPool,
      onEventTap: widget.onEventTap,
    );
  }
}

/// Crossfade + colapso de altura entre skeleton / anuncio / vacío.
///
/// El [child] debe llevar una [Key] distinta por estado (p. ej. id del anuncio).
class SponsoredAdReveal extends StatelessWidget {
  const SponsoredAdReveal({super.key, required this.child});

  final Widget child;

  static const fadeDuration = Duration(milliseconds: 340);
  static const sizeDuration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: sizeDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: fadeDuration,
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: child,
      ),
    );
  }
}

/// Reveal compartido (slots en feed + barras del shell).
class SponsoredAdAsyncReveal extends StatelessWidget {
  const SponsoredAdAsyncReveal({
    super.key,
    required this.adAsync,
    this.style = SponsoredAdCardStyle.banner,
    this.compact = false,
    this.sectionLabel,
    this.padding,
    this.event,
    this.linkEventPool,
    this.onEventTap,
  });

  final AsyncValue<SponsoredAd?> adAsync;
  final SponsoredAdCardStyle style;
  final bool compact;
  final String? sectionLabel;
  final EdgeInsetsGeometry? padding;
  final CalendarEvent? event;
  final List<CalendarEvent>? linkEventPool;
  final ValueChanged<CalendarEvent>? onEventTap;

  @override
  Widget build(BuildContext context) {
    final child = adAsync.when(
      skipLoadingOnReload: true,
      data: (ad) {
        if (ad == null) {
          return const SizedBox.shrink(key: ValueKey('ad-empty'));
        }
        return KeyedSubtree(
          key: ValueKey('ad-${ad.id}'),
          child: _buildContent(ad),
        );
      },
      // Shell docked: sin skeleton en frío → evita salto nav si no hay inventario.
      // En reload, skipLoadingOnReload mantiene el anuncio anterior.
      loading: () {
        if (style == SponsoredAdCardStyle.forumsDocked) {
          return const SizedBox.shrink(key: ValueKey('ad-loading-docked'));
        }
        return KeyedSubtree(
          key: ValueKey('ad-loading-${style.name}-$compact'),
          child: _wrapPadding(
            SponsoredAdSkeleton(style: style, compact: compact),
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(key: ValueKey('ad-error')),
    );

    return SponsoredAdReveal(child: child);
  }

  Widget _buildContent(SponsoredAd ad) {
    final linkedEvent = event ??
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

    return _wrapPadding(content);
  }

  Widget _wrapPadding(Widget child) {
    if (padding == null) return child;
    return Padding(padding: padding!, child: child);
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
