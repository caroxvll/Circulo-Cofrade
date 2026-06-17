import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../../shared/models/calendar_event.dart';

/// Icono de tipo de evento: usa tu imagen en assets/icons/ si existe,
/// si no, muestra el icono Material de respaldo.
class EventTypeIcon extends StatelessWidget {
  const EventTypeIcon({
    super.key,
    required this.type,
    this.size = 52,
  });

  final EventType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = AppAssets.eventIconPath(type);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundElevated,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              _fallbackIcon(type),
              color: AppColors.burgundy,
              size: size * 0.42,
            );
          },
        ),
      ),
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
