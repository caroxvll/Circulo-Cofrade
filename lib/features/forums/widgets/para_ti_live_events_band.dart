import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/minute_clock.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/event_type_icon.dart';
import '../../../shared/models/calendar_event.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../../cuaresma/cuaresma_ensayos_provider.dart';
import '../../cuaresma/utils/cuaresma_topic.dart';

const _circuloForumId = 'foro-cofradiero';

/// Banda fija de Para ti: en curso, lo que sale, y lo ya cerrado hasta medianoche.
class ParaTiLiveEventsBand extends ConsumerWidget {
  const ParaTiLiveEventsBand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchMinuteClock(ref);
    final events =
        ref.watch(todayParaTiLiveEventsProvider).asData?.value ??
        const <CalendarEvent>[];
    if (events.isEmpty) return const SizedBox.shrink();

    final anyLive = events.any((event) => _isLive(event, now: now));
    final onlyFinished = !anyLive &&
        events.every((event) => _isFinished(event, now: now));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              if (anyLive) ...[
                const _LiveDot(),
                const SizedBox(width: 6),
              ],
              Text(
                anyLive
                    ? 'EN VIVO'
                    : onlyFinished
                        ? 'HOY · FINALIZADOS'
                        : 'HOY',
                style: AppTypography.labelSmall(
                  color: anyLive ? AppColors.liveGreen : AppColors.goldDark,
                ).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.7,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        if (events.length == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: _LiveEventChip(
              event: events.first,
              expanded: true,
              now: now,
            ),
          )
        else
          SizedBox(
            height: 74,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) => true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _LiveEventChip(event: events[index], now: now);
                },
              ),
            ),
          ),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
      ],
    );
  }
}

class _LiveEventChip extends StatelessWidget {
  const _LiveEventChip({
    required this.event,
    required this.now,
    this.expanded = false,
  });

  final CalendarEvent event;
  final DateTime now;
  final bool expanded;

  static final _fill = Color.alphaBlend(
    AppColors.goldPale.withValues(alpha: 0.72),
    AppColors.background,
  );

  @override
  Widget build(BuildContext context) {
    final live = _isLive(event, now: now);
    final finished = _isFinished(event, now: now);
    final name = _eventName(event);
    final timing = _timingLabel(event, now: now);
    final accent = live
        ? AppColors.liveGreen
        : finished
            ? AppColors.textMuted
            : AppColors.burgundy;
    final fill = finished
        ? Color.alphaBlend(
            AppColors.backgroundElevated.withValues(alpha: 0.7),
            AppColors.surface,
          )
        : _fill;

    return _LiveAura(
      live: live,
      finished: finished,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: expanded ? double.infinity : 196,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  EventTypeIcon(
                    type: event.type,
                    size: 36,
                    customIconUrl: event.customIconUrl,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_typeLabel(event.type)} · $timing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall(
                            color: accent,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.hermandadName().copyWith(
                            fontSize: 16,
                            height: 1.05,
                            color: finished ? AppColors.textSecondary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    finished
                        ? Icons.history_rounded
                        : Icons.chevron_right_rounded,
                    color: accent,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final id = event.id;
    if (id == null || id.isEmpty) return;
    if (event.type.opensCuaresmaLive) {
      context.push(
        '/foros/$_circuloForumId/tema/$cuaresmaTopicId/ensayo/$id',
      );
      return;
    }
    context.push(
      '/foros/$_circuloForumId/tema/$cuaresmaTopicId?cita=$id',
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          final ring = (math.sin(t * math.pi * 2) + 1) / 2;
          return CustomPaint(
            painter: _LiveDotPainter(ring: ring),
          );
        },
      ),
    );
  }
}

class _LiveDotPainter extends CustomPainter {
  const _LiveDotPainter({required this.ring});

  final double ring;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      5.2 + ring * 1.6,
      Paint()
        ..color = AppColors.liveGreen.withValues(alpha: 0.22 - ring * 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      3.4,
      Paint()..color = AppColors.liveGreen,
    );
  }

  @override
  bool shouldRepaint(_LiveDotPainter oldDelegate) => oldDelegate.ring != ring;
}

/// Borde que recorre el recuadro: oro si es de hoy, verde si está en vivo.
/// Los finalizados se quedan quietos, con un borde suave.
class _LiveAura extends StatefulWidget {
  const _LiveAura({
    required this.live,
    required this.child,
    this.finished = false,
  });

  final bool live;
  final bool finished;
  final Widget child;

  @override
  State<_LiveAura> createState() => _LiveAuraState();
}

class _LiveAuraState extends State<_LiveAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.live ? 3200 : 5200),
    );
    if (!widget.finished) _spin.repeat();
  }

  @override
  void didUpdateWidget(_LiveAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live == widget.live &&
        oldWidget.finished == widget.finished) {
      return;
    }
    _spin.duration = Duration(milliseconds: widget.live ? 3200 : 5200);
    if (widget.finished) {
      _spin.stop();
    } else {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.finished) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _LiveAuraPainter(
            t: _spin.value,
            live: widget.live,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _LiveAuraPainter extends CustomPainter {
  const _LiveAuraPainter({required this.t, required this.live});

  final double t;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    ).deflate(0.7);
    final rect = Offset.zero & size;
    final head = live ? AppColors.liveGreen : AppColors.gold;
    final tail = live ? AppColors.gold : AppColors.goldDark;
    final breathe = 0.55 + 0.45 * math.sin(t * math.pi * 2);

    if (live) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = head.withValues(alpha: 0.05 + breathe * 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );
    }

    final shader = SweepGradient(
      startAngle: t * math.pi * 2,
      endAngle: t * math.pi * 2 + math.pi * 2,
      colors: [
        head.withValues(alpha: 0),
        head.withValues(alpha: live ? 0.9 : 0.55),
        tail.withValues(alpha: live ? 0.45 : 0.28),
        head.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.08, 0.22, 0.42],
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = live ? 1.55 : 1.2
        ..shader = shader,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = (live ? AppColors.liveGreen : AppColors.gold)
            .withValues(alpha: live ? 0.16 : 0.22),
    );
  }

  @override
  bool shouldRepaint(_LiveAuraPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.live != live;
}

bool _isLive(CalendarEvent event, {required DateTime now}) {
  return calendarEventTiming(event, now: now)?.kind ==
      CalendarEventTimingKind.inProgress;
}

bool _isFinished(CalendarEvent event, {required DateTime now}) {
  if (event.liveForceState == EventLiveForceState.closed) return true;
  return calendarEventTiming(event, now: now)?.kind ==
      CalendarEventTimingKind.finished;
}

String _eventName(CalendarEvent event) {
  final organizer = event.organizerLabel?.trim();
  if (organizer != null && organizer.isNotEmpty) return organizer;
  final title = event.title.trim();
  if (title.isNotEmpty) return title;
  return _typeLabel(event.type);
}

String _typeLabel(EventType type) {
  return switch (type) {
    EventType.ensayo => 'ENSAYO',
    EventType.iguala => 'IGUALÁ',
    EventType.concierto => 'CONCIERTO',
    _ => type.cellLabel.toUpperCase(),
  };
}

String _timingLabel(CalendarEvent event, {required DateTime now}) {
  final timing = calendarEventTiming(event, now: now);
  final time = event.time?.trim();
  if (timing == null) {
    return (time != null && time.isNotEmpty) ? time : 'Hoy';
  }
  if (timing.kind == CalendarEventTimingKind.scheduled &&
      time != null &&
      time.isNotEmpty) {
    return time;
  }
  if (event.type == EventType.ensayo &&
      timing.kind == CalendarEventTimingKind.startsSoon) {
    return timing.label.replaceFirst('Empieza', 'Sale');
  }
  return timing.label;
}
