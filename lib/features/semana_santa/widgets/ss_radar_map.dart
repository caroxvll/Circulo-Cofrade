import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../forums/topic_detail_typography.dart';
import '../utils/ss_map_logic.dart';
import 'ss_live_design.dart';

/// Colores rotativos para distinguir hermandades en el mapa.
const _trackPalette = <Color>[
  AppColors.burgundy,
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFF00838F),
  AppColors.goldDark,
];

Color ssTrackColorForKey(String key) {
  final hash = key.hashCode.abs();
  return _trackPalette[hash % _trackPalette.length];
}

class SsRadarMap extends StatefulWidget {
  const SsRadarMap({
    super.key,
    required this.tracks,
    this.height = 340,
    this.onTrackTap,
  });

  final List<SsHermandadTrack> tracks;
  final double height;
  final ValueChanged<SsHermandadTrack>? onTrackTap;

  @override
  State<SsRadarMap> createState() => _SsRadarMapState();
}

class _SsRadarMapState extends State<SsRadarMap> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.tracks.isEmpty
        ? const LatLng(sevillaMapCenterLat, sevillaMapCenterLng)
        : LatLng(
            widget.tracks.map((t) => t.latitude).reduce((a, b) => a + b) /
                widget.tracks.length,
            widget.tracks.map((t) => t.longitude).reduce((a, b) => a + b) /
                widget.tracks.length,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14.2,
                minZoom: 12,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cofradeo.app',
                ),
                PolylineLayer(
                  polylines: [
                    for (final track in widget.tracks)
                      if (track.pointCount >= 2)
                        Polyline(
                          points: [
                            for (final p in track.pointsOldestFirst)
                              LatLng(p.latitude!, p.longitude!),
                          ],
                          strokeWidth: 4.5,
                          color: ssTrackColorForKey(track.key).withValues(alpha: 0.85),
                          borderStrokeWidth: 1.5,
                          borderColor: Colors.white.withValues(alpha: 0.7),
                        ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final track in widget.tracks)
                      Marker(
                        point: LatLng(track.latitude, track.longitude),
                        width: 120,
                        height: 54,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => widget.onTrackTap?.call(track),
                          child: _HermandadHeadPin(
                            track: track,
                            color: ssTrackColorForKey(track.key),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (widget.tracks.isEmpty)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'El mapa marca el recorrido de las hermandades.\nPublica un aviso de «Recorrido» con ubicación para empezar el rastro.',
                        textAlign: TextAlign.center,
                        style: TopicDetailTypography.meta(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.tracks.isEmpty
                      ? 'Sin hermandades en mapa'
                      : '${widget.tracks.length} hermandad${widget.tracks.length == 1 ? '' : 'es'} en calle',
                  style: TopicDetailTypography.meta(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: 'Centrar Sevilla',
                  onPressed: () {
                    _mapController.move(
                      const LatLng(sevillaMapCenterLat, sevillaMapCenterLng),
                      14.2,
                    );
                  },
                  icon: const Icon(
                    Icons.my_location_outlined,
                    color: AppColors.burgundy,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HermandadHeadPin extends StatelessWidget {
  const _HermandadHeadPin({
    required this.track,
    required this.color,
  });

  final SsHermandadTrack track;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            track.shortLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TopicDetailTypography.meta(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ).copyWith(fontSize: 10),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(Icons.place, color: Colors.white, size: 11),
        ),
      ],
    );
  }
}

Future<void> showSsTrackSheet(
  BuildContext context, {
  required SsHermandadTrack track,
}) {
  final color = ssTrackColorForKey(track.key);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final points = track.pointsOldestFirst.reversed.take(6).toList();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      track.hermandadLabel,
                      style: TopicDetailTypography.body().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                track.pointCount == 1
                    ? 'Última posición publicada'
                    : 'Rastro con ${track.pointCount} puntos de la comunidad',
                style: TopicDetailTypography.meta(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...points.map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SsLiveUpdateTile(update: u),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
