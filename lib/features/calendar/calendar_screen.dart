import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';



import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/calendar_event.dart';
import '../auth/auth_provider.dart';
import 'calendar_provider.dart';
import 'models/calendar_focus_request.dart';
import 'models/calendar_upcoming_snapshot.dart';
import 'utils/calendar_event_utils.dart';
import 'widgets/calendar_upcoming_banner.dart';
import 'widgets/cofradeo_calendar.dart';

import 'widgets/event_card.dart';

import 'widgets/event_compose_sheet.dart';

import 'widgets/event_detail_sheet.dart';

import 'widgets/filter_chip_row.dart';

import 'widgets/month_events_sheet.dart';



class CalendarScreen extends ConsumerStatefulWidget {

  const CalendarScreen({super.key});



  @override

  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();

}



class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedMonth;
  EventFilter _filter = EventFilter.todas;
  int? _selectedDay;
  var _monthInitialized = false;
  var _autoSelectedToday = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_monthInitialized) return;
    _monthInitialized = true;
    _focusedMonth = calendarDefaultMonth(
      supabaseReady: ref.read(supabaseReadyProvider),
    );
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month);
      _selectedDay = now.day;
    });
  }

  void _maybeAutoSelectToday(List<CalendarEvent> events) {
    if (!ref.read(supabaseReadyProvider)) return;
    if (_autoSelectedToday || _selectedDay != null) return;
    if (!isCurrentCalendarMonth(_focusedMonth)) return;
    final today = DateTime.now().day;
    if (eventsOnDay(events, _focusedMonth, today).isEmpty) return;
    _autoSelectedToday = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _selectedDay = today);
    });
  }

  void _onFilterChanged(EventFilter filter) {

    setState(() {

      _filter = filter;

      if (_selectedDay != null) {

        final events = ref.read(calendarEventsProvider(_focusedMonth)).asData?.value ?? [];

        final stillVisible = eventsOnDay(events, _focusedMonth, _selectedDay!)

            .any(filter.matches);

        if (!stillVisible) _selectedDay = null;

      }

    });

  }



  void _onMonthChanged(DateTime month) {

    setState(() {

      _focusedMonth = month;

      _selectedDay = null;

    });

  }



  void _onDayTap(int day, List<CalendarEvent> events) {

    setState(() {

      if (events.isEmpty) {

        _selectedDay = null;

        return;

      }

      _selectedDay = _selectedDay == day ? null : day;

    });

  }



  void _openMonthEventsSheet(List<CalendarEvent> monthEvents) {

    MonthEventsSheet.show(

      context,

      month: _focusedMonth,

      events: monthEvents,

      onEventTap: (event) {

        Navigator.pop(context);

        setState(() => _selectedDay = event.date.day);

        showEventDetailSheet(

          context,

          ref,

          event: event,

          focusedMonth: _focusedMonth,

        );

      },

    );

  }



  void _onEventTap(CalendarEvent event) {

    showEventDetailSheet(

      context,

      ref,

      event: event,

      focusedMonth: _focusedMonth,

    );

  }

  void _applyCalendarFocus(CalendarFocusRequest? request) {
    if (request == null) return;

    setState(() {
      _focusedMonth = DateTime(request.month.year, request.month.month);
      _selectedDay = request.day;
    });

    final event = request.event;
    if (event == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showEventDetailSheet(
        context,
        ref,
        event: event,
        focusedMonth: _focusedMonth,
      );
    });
  }



  void _onCreateEvent() {

    final initialDate = _selectedDay == null

        ? DateTime(_focusedMonth.year, _focusedMonth.month, 1)

        : DateTime(_focusedMonth.year, _focusedMonth.month, _selectedDay!);

    showEventComposeSheet(context, ref, initialDate: initialDate);

  }



  @override

  Widget build(BuildContext context) {

    ref.listen<CalendarFocusRequest?>(calendarFocusRequestProvider, (_, next) {
      if (next == null) return;
      ref.read(calendarFocusRequestProvider.notifier).setFocus(null);
      _applyCalendarFocus(next);
    });

    final pendingFocus = ref.read(calendarFocusRequestProvider);
    if (pendingFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final request = ref.read(calendarFocusRequestProvider.notifier).take();
        _applyCalendarFocus(request);
      });
    }

    final eventsAsync = ref.watch(calendarEventsProvider(_focusedMonth));
    final upcomingAsync = ref.watch(calendarUpcomingProvider);
    final canEdit = ref.watch(isCalendarEditorProvider);



    return Scaffold(

      backgroundColor: AppColors.background,

      floatingActionButton: canEdit

          ? FloatingActionButton.extended(

              onPressed: _onCreateEvent,

              backgroundColor: AppColors.burgundy,

              foregroundColor: AppColors.textOnDark,

              icon: const Icon(Icons.add),

              label: const Text('Evento'),

            )

          : null,

      body: SafeArea(

        bottom: false,

        child: eventsAsync.when(

          loading: () => const Center(child: CircularProgressIndicator()),

          error: (_, __) => _CalendarBody(

            focusedMonth: _focusedMonth,

            filter: _filter,

            selectedDay: _selectedDay,

            events: const [],

            onFilterChanged: _onFilterChanged,

            onMonthChanged: _onMonthChanged,

            onDayTap: _onDayTap,

            onViewAll: () {},

            onEventTap: _onEventTap,

            onClearSelection: () => setState(() => _selectedDay = null),
            onGoToToday: _goToToday,
            emptyMessage: 'No se pudieron cargar los eventos.',
          ),
          data: (events) {
            _maybeAutoSelectToday(events);
            final monthEvents = eventsForMonth(events, _focusedMonth, filter: _filter);

            final selectedEvents = _selectedDay == null

                ? <CalendarEvent>[]

                : eventsOnDay(events, _focusedMonth, _selectedDay!)

                    .where(_filter.matches)

                    .toList();



            return RefreshIndicator(

              onRefresh: () async {
                invalidateCalendarData(ref, _focusedMonth);
                await ref.read(calendarEventsProvider(_focusedMonth).future);
              },
              child: _CalendarBody(
                focusedMonth: _focusedMonth,
                filter: _filter,
                selectedDay: _selectedDay,
                events: events,
                monthEvents: monthEvents,
                selectedEvents: selectedEvents,
                upcomingSnapshot: upcomingAsync.asData?.value,
                onGoToToday: _goToToday,
                onFilterChanged: _onFilterChanged,
                onMonthChanged: _onMonthChanged,
                onDayTap: _onDayTap,
                onViewAll: () => _openMonthEventsSheet(monthEvents),
                onEventTap: _onEventTap,
                onClearSelection: () => setState(() => _selectedDay = null),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.focusedMonth,
    required this.filter,
    required this.selectedDay,
    required this.events,
    required this.onFilterChanged,
    required this.onMonthChanged,
    required this.onDayTap,
    required this.onViewAll,
    required this.onEventTap,
    required this.onClearSelection,
    required this.onGoToToday,
    this.monthEvents,
    this.selectedEvents,
    this.upcomingSnapshot,
    this.emptyMessage,
  });

  final DateTime focusedMonth;
  final EventFilter filter;
  final int? selectedDay;
  final List<CalendarEvent> events;
  final List<CalendarEvent>? monthEvents;
  final List<CalendarEvent>? selectedEvents;
  final CalendarUpcomingSnapshot? upcomingSnapshot;
  final ValueChanged<EventFilter> onFilterChanged;
  final ValueChanged<DateTime> onMonthChanged;
  final void Function(int day, List<CalendarEvent> events) onDayTap;
  final VoidCallback onViewAll;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onClearSelection;
  final VoidCallback onGoToToday;
  final String? emptyMessage;



  @override

  Widget build(BuildContext context) {

    if (emptyMessage != null) {

      return Center(

        child: Padding(

          padding: const EdgeInsets.all(24),

          child: Text(emptyMessage!, style: AppTypography.bodyLarge()),

        ),

      );

    }



    final monthList = monthEvents ?? eventsForMonth(events, focusedMonth, filter: filter);

    final dayList = selectedEvents ??

        (selectedDay == null

            ? <CalendarEvent>[]

            : eventsOnDay(events, focusedMonth, selectedDay!)

                .where(filter.matches)

                .toList());



    return CustomScrollView(

      physics: const AlwaysScrollableScrollPhysics(),

      slivers: [

        SliverPadding(

          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),

          sliver: SliverToBoxAdapter(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Calendario',
                        style: AppTypography.displayLarge(),
                      ),
                    ),
                    if (!isCurrentCalendarMonth(focusedMonth))
                      TextButton(
                        onPressed: onGoToToday,
                        child: Text(
                          'Ir a hoy',
                          style: AppTypography.bodyMedium(
                            color: AppColors.burgundy,
                          ),
                        ),
                      ),
                  ],
                ),
                if (upcomingSnapshot != null && upcomingSnapshot!.hasAny) ...[
                  const SizedBox(height: 16),
                  CalendarUpcomingBanner(
                    snapshot: upcomingSnapshot!,
                    onEventTap: onEventTap,
                  ),
                ],
                const SizedBox(height: 16),
                FilterChipRow(

                  selected: filter,

                  onSelected: onFilterChanged,

                ),

              ],

            ),

          ),

        ),

        SliverPadding(

          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),

          sliver: SliverToBoxAdapter(

            child: Container(

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                color: AppColors.surface,

                borderRadius: BorderRadius.circular(16),

                border: Border.all(color: AppColors.border),

              ),

              child: CofradeoCalendar(

                focusedMonth: focusedMonth,

                events: events,

                filter: filter,

                selectedDay: selectedDay,

                onMonthChanged: onMonthChanged,

                onDayTap: onDayTap,

              ),

            ),

          ),

        ),

        SliverPadding(

          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),

          sliver: SliverToBoxAdapter(

            child: _EventsSectionHeader(

              selectedDay: selectedDay,

              focusedMonth: focusedMonth,

              monthEventCount: monthList.length,

              onViewAll: monthList.isEmpty ? null : onViewAll,

              onClearSelection:

                  selectedDay == null ? null : onClearSelection,

            ),

          ),

        ),

        SliverPadding(

          padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),

          sliver: SliverToBoxAdapter(

            child: _EventsSectionBody(

              selectedDay: selectedDay,

              selectedEvents: dayList,

              monthEventCount: monthList.length,

              onViewAll: onViewAll,

              onEventTap: onEventTap,

            ),

          ),

        ),

      ],

    );

  }

}



class _EventsSectionHeader extends StatelessWidget {

  const _EventsSectionHeader({

    required this.selectedDay,

    required this.focusedMonth,

    required this.monthEventCount,

    this.onViewAll,

    this.onClearSelection,

  });



  final int? selectedDay;

  final DateTime focusedMonth;

  final int monthEventCount;

  final VoidCallback? onViewAll;

  final VoidCallback? onClearSelection;



  @override

  Widget build(BuildContext context) {

    final title = selectedDay == null

        ? 'Eventos del mes'

        : DateFormat("d 'de' MMMM", 'es').format(

            DateTime(focusedMonth.year, focusedMonth.month, selectedDay!),

          );



    return Row(

      crossAxisAlignment: CrossAxisAlignment.center,

      children: [

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                title,

                style: AppTypography.titleLarge().copyWith(fontSize: 18),

              ),

              if (selectedDay == null && monthEventCount > 0)

                Text(

                  '$monthEventCount eventos · Toca un día resaltado',

                  style: AppTypography.bodyMedium(),

                ),

            ],

          ),

        ),

        if (selectedDay != null && onClearSelection != null)

          TextButton(

            onPressed: onClearSelection,

            child: Text(

              'Limpiar',

              style: AppTypography.bodyMedium(color: AppColors.burgundy),

            ),

          )

        else if (onViewAll != null)

          TextButton(

            onPressed: onViewAll,

            child: Text(

              'Ver todos',

              style: AppTypography.bodyMedium(color: AppColors.burgundy),

            ),

          ),

      ],

    );

  }

}



class _EventsSectionBody extends StatelessWidget {

  const _EventsSectionBody({

    required this.selectedDay,

    required this.selectedEvents,

    required this.monthEventCount,

    required this.onViewAll,

    required this.onEventTap,

  });



  final int? selectedDay;

  final List<CalendarEvent> selectedEvents;

  final int monthEventCount;

  final VoidCallback onViewAll;

  final ValueChanged<CalendarEvent> onEventTap;



  @override

  Widget build(BuildContext context) {

    if (selectedDay != null) {

      if (selectedEvents.isEmpty) {

        return const _EmptyHint(

          message: 'No hay eventos de este tipo en el día seleccionado.',

        );

      }

      return Column(

        children: [

          for (var i = 0; i < selectedEvents.length; i++) ...[

            if (i > 0) const SizedBox(height: 12),

            EventCard(

              event: selectedEvents[i],

              highlighted: true,

              onTap: () => onEventTap(selectedEvents[i]),

            ),

          ],

        ],

      );

    }



    if (monthEventCount == 0) {

      return const _EmptyHint(

        message: 'No hay eventos para este filtro en el mes.',

      );

    }



    return _MonthSummaryCard(

      eventCount: monthEventCount,

      onViewAll: onViewAll,

    );

  }

}



class _EmptyHint extends StatelessWidget {

  const _EmptyHint({required this.message});



  final String message;



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: AppColors.surfaceAlt,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: AppColors.border),

      ),

      child: Text(

        message,

        style: AppTypography.bodyMedium(),

        textAlign: TextAlign.center,

      ),

    );

  }

}



class _MonthSummaryCard extends StatelessWidget {

  const _MonthSummaryCard({

    required this.eventCount,

    required this.onViewAll,

  });



  final int eventCount;

  final VoidCallback onViewAll;



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: AppColors.border),

      ),

      child: Column(

        children: [

          Icon(Icons.touch_app_outlined, color: AppColors.goldDark, size: 32),

          const SizedBox(height: 12),

          Text(

            'Selecciona un día marcado en el calendario',

            style: AppTypography.titleLarge().copyWith(fontSize: 16),

            textAlign: TextAlign.center,

          ),

          const SizedBox(height: 8),

          Text(

            'Verás aquí solo la información de ese evento.',

            style: AppTypography.bodyMedium(),

            textAlign: TextAlign.center,

          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(

            onPressed: onViewAll,

            icon: const Icon(Icons.list_alt, size: 18),

            label: Text('Ver los $eventCount eventos del mes'),

            style: OutlinedButton.styleFrom(

              foregroundColor: AppColors.burgundy,

              side: const BorderSide(color: AppColors.burgundy),

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(12),

              ),

            ),

          ),

        ],

      ),

    );

  }

}


