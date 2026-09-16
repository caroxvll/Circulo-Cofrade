import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/calendar_event.dart';
import '../../calendar/calendar_provider.dart';
import '../../calendar/utils/calendar_event_utils.dart';
import '../admin_provider.dart';
import '../junta_ui.dart';

class JuntaPendingEventsTab extends ConsumerWidget {
  const JuntaPendingEventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(pendingCalendarEventsProvider);

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Error al cargar eventos: $e',
          style: JuntaUi.body(color: AppColors.accentRed),
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return const JuntaEmptyPanel(
            icon: Icons.event_busy_outlined,
            message: 'No hay eventos pendientes de aprobación.',
          );
        }

        return ListView.separated(
          padding: JuntaUi.listPadding,
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: JuntaUi.itemGap),
          itemBuilder: (context, index) {
            return _PendingEventCard(event: events[index]);
          },
        );
      },
    );
  }
}

class _PendingEventCard extends ConsumerStatefulWidget {
  const _PendingEventCard({required this.event});

  final CalendarEvent event;

  @override
  ConsumerState<_PendingEventCard> createState() => _PendingEventCardState();
}

class _PendingEventCardState extends ConsumerState<_PendingEventCard> {
  var _busy = false;

  void _refreshCalendar() {
    ref.invalidate(pendingCalendarEventsProvider);
    ref.invalidate(calendarUpcomingProvider);
    ref.invalidate(calendarEventsProvider);
  }

  Future<void> _publish() async {
    final eventId = widget.event.id;
    if (eventId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).setCalendarEventStatus(
            eventId: eventId,
            status: CalendarEventStatus.published,
          );
      _refreshCalendar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento publicado en el calendario')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo publicar el evento')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final eventId = widget.event.id;
    if (eventId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).deleteCalendarEvent(eventId);
      _refreshCalendar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento rechazado y eliminado')),
        );
      }
    } on CalendarEventDeleteFailedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarDeleteErrorMessage(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarDeleteErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final publisher = event.publisherHandle;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: JuntaUi.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: JuntaUi.cardTitle()),
            const SizedBox(height: 4),
            Text(
              '${event.type.label} · ${event.date.day}/${event.date.month}/${event.date.year}'
              '${event.time != null ? ' · ${event.time}' : ''}',
              style: JuntaUi.caption(),
            ),
            if (event.subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(event.subtitle, style: JuntaUi.body()),
            ],
            if (publisher != null && publisher.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Propuesto por @$publisher',
                style: JuntaUi.caption(color: AppColors.burgundy),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _publish,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.burgundy,
                      foregroundColor: AppColors.textOnDark,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
