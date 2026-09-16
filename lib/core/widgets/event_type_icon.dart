import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../utils/image_decode_cache.dart';
import 'cofradeo_network_image.dart';
import '../../shared/models/calendar_event.dart';

/// Icono de tipo de evento: usa tu imagen en assets/icons/ si existe,
/// si no, muestra el icono Material de respaldo.
class EventTypeIcon extends StatelessWidget {
  const EventTypeIcon({
    super.key,
    required this.type,
    this.size = 52,
    this.customIconUrl,
    this.roundedSquare = false,
  });

  final EventType type;
  final double size;
  final String? customIconUrl;
  final bool roundedSquare;

  @override
  Widget build(BuildContext context) {
    final iconPath = customIconUrl?.trim().isNotEmpty == true
        ? customIconUrl!.trim()
        : AppAssets.eventIconPath(type);
    final fallback = Icon(
      _fallbackIcon(type),
      color: AppColors.burgundy,
      size: size * 0.42,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: roundedSquare ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: roundedSquare ? BorderRadius.circular(16) : null,
        color: AppColors.backgroundElevated,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _IconImage(path: iconPath, size: size, fallback: fallback),
    );
  }

  static IconData _fallbackIcon(EventType type) {
    return switch (type) {
      EventType.procesion => Icons.church,
      EventType.gloria => Icons.wb_sunny_outlined,
      EventType.ensayo => Icons.groups_outlined,
      EventType.iguala => Icons.handshake_outlined,
      EventType.concierto => Icons.music_note,
      EventType.evento => Icons.event_outlined,
    };
  }
}

class _IconImage extends StatelessWidget {
  const _IconImage({
    required this.path,
    required this.size,
    required this.fallback,
  });

  final String path;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final normalizedPath = path.toLowerCase().split('?').first;
    final isSvg = normalizedPath.endsWith('.svg');
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');

    if (isSvg && isNetwork) {
      return SvgPicture.network(
        path,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => fallback,
      );
    }
    if (isSvg) {
      return SvgPicture.asset(
        path,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => fallback,
      );
    }
    if (isNetwork) {
      return CofradeoNetworkImage(
        url: path,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheSize: size,
        placeholder: fallback,
        errorWidget: fallback,
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: size,
      height: size,
      filterQuality: FilterQuality.low,
      cacheWidth: ImageDecodeCache.px(context, size),
      cacheHeight: ImageDecodeCache.px(context, size),
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
