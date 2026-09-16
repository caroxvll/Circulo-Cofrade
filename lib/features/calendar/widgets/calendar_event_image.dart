import 'package:flutter/material.dart';

import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../shared/models/calendar_event.dart';

/// Imagen de portada con fallback limpio (sin patrón damasco).
class CalendarEventImage extends StatelessWidget {
  const CalendarEventImage({
    super.key,
    required this.event,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = BorderRadius.zero,
    this.showTypeFallback = true,
    this.compact = false,
  });

  final CalendarEvent event;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius borderRadius;
  final bool showTypeFallback;
  final bool compact;

  static bool hasDisplayableCover(CalendarEvent event) {
    final cover = event.coverImageUrl?.trim();
    return cover != null && cover.isNotEmpty && !_isPatternPlaceholder(cover);
  }

  static bool _isPatternPlaceholder(String url) {
    final normalized = url.toLowerCase();
    return normalized.contains('fondo.jpeg') ||
        normalized.contains('fondobeige');
  }

  @override
  Widget build(BuildContext context) {
    final cover = event.coverImageUrl?.trim();
    final hasCover = cover != null && cover.isNotEmpty && !_isPatternPlaceholder(cover);
    final isAsset = hasCover && cover.startsWith('assets/');

    Widget child;
    if (hasCover && isAsset) {
      child = Image.asset(
        cover,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        cacheWidth: ImageDecodeCache.px(
          context,
          MediaQuery.sizeOf(context).width.clamp(320.0, 1080.0),
        ),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (hasCover) {
      final cacheSize =
          MediaQuery.sizeOf(context).width.clamp(320.0, 1080.0);
      child = CofradeoNetworkImage(
        url: cover,
        fit: fit,
        alignment: alignment,
        cacheSize: cacheSize,
        filterQuality: FilterQuality.medium,
        errorWidget: _fallback(),
      );
    } else {
      child = _fallback();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: compact
              ? const [Color(0xFF5A0610), Color(0xFF7A0814)]
              : const [
                  Color(0xFF3D0008),
                  Color(0xFF5A0610),
                  Color(0xFF7A0814),
                ],
          stops: compact ? null : const [0.0, 0.55, 1.0],
        ),
      ),
      child: showTypeFallback && !compact
          ? Center(
              child: Opacity(
                opacity: 0.35,
                child: EventTypeIcon(
                  type: event.type,
                  size: 56,
                  customIconUrl: event.customIconUrl,
                ),
              ),
            )
          : null,
    );
  }
}
