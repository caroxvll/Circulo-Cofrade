import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/calendar_event.dart';
import '../auth/auth_provider.dart';
import '../forums/widgets/forums_beige_background.dart';
import '../notifications/widgets/notifications_bell_button.dart';
import '../../core/widgets/cofrade_countdown_banner.dart';
import '../../core/widgets/cofradeo_error_panel.dart';
import 'calendar_design_tokens.dart';
import 'calendar_provider.dart';
import 'event_bookmarks_provider.dart';
import 'models/calendar_focus_request.dart';
import 'utils/calendar_event_utils.dart';
import 'liturgical_countdown_provider.dart';
import 'widgets/calendar_hero_carousel.dart';
import 'widgets/calendar_month_sheet.dart';
import 'widgets/calendar_week_strip.dart';
import 'widgets/event_card.dart';
import 'widgets/event_compose_sheet.dart';
import 'widgets/event_detail_sheet.dart';
import 'widgets/filter_chip_row.dart';
import 'widgets/month_events_sheet.dart';
import 'widgets/organizer_picker_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  EventFilter _filter = EventFilter.todas;
  var _monthInitialized = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  var _searchQuery = '';
  var _searching = false;
  List<CalendarEvent> _searchResults = const [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_monthInitialized) return;
    _monthInitialized = true;
    final now = DateTime.now();
    _focusedMonth = calendarDefaultMonth(
      supabaseReady: ref.read(supabaseReadyProvider),
    );
    _selectedDate = ref.read(supabaseReadyProvider)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(_focusedMonth.year, _focusedMonth.month, 23);
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      if (_focusedMonth.year != date.year || _focusedMonth.month != date.month) {
        _focusedMonth = DateTime(date.year, date.month);
      }
    });
  }

  void _onFilterChanged(EventFilter filter) {
    setState(() => _filter = filter);
  }

  void _onMonthChanged(DateTime month) {
    setState(() {
      _focusedMonth = month;
      if (_selectedDate.year != month.year || _selectedDate.month != month.month) {
        final day = _selectedDate.day.clamp(1, DateUtils.getDaysInMonth(month.year, month.month));
        _selectedDate = DateTime(month.year, month.month, day);
      }
    });
  }

  void _onDayTap(int day, List<CalendarEvent> events) {
    _onDateSelected(DateTime(_focusedMonth.year, _focusedMonth.month, day));
    Navigator.of(context).maybePop();
  }

  void _openDayEventsSheet(List<CalendarEvent> dayEvents) {
    DayEventsSheet.show(
      context,
      day: _selectedDate,
      events: dayEvents,
      onEventTap: (event) {
        Navigator.pop(context);
        _onEventTap(event);
      },
    );
  }

  void _openMonthCalendar(List<CalendarEvent> events) {
    CalendarMonthSheet.show(
      context,
      focusedMonth: _focusedMonth,
      events: events,
      filter: _filter,
      selectedDay: _selectedDayInMonth,
      onMonthChanged: _onMonthChanged,
      onDayTap: _onDayTap,
    );
  }

  int? get _selectedDayInMonth {
    if (_selectedDate.year == _focusedMonth.year &&
        _selectedDate.month == _focusedMonth.month) {
      return _selectedDate.day;
    }
    return null;
  }

  void _onEventTap(CalendarEvent event) {
    showEventDetailSheet(
      context,
      ref,
      event: event,
      focusedMonth: _focusedMonth,
    );
  }

  Future<void> _toggleBookmark(CalendarEvent event) async {
    if (!ref.read(canEngageProvider)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para guardar eventos'),
        ),
      );
      return;
    }

    try {
      final added =
          await ref.read(eventBookmarkIdsProvider.notifier).toggle(event);
      if (!mounted || added == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Evento guardado' : 'Quitado de guardados',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el guardado')),
      );
    }
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = query;
      _searching = query.length >= 2;
      if (query.length < 2) _searchResults = const [];
    });

    if (query.length < 2) return;

    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await ref
          .read(calendarRepositoryProvider)
          .searchEvents(query, limit: 10);
      if (!mounted || query != _searchQuery) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || query != _searchQuery) return;
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searching = false;
      _searchResults = const [];
    });
  }

  void _onSearchEventTap(CalendarEvent event) {
    final eventMonth = DateTime(event.date.year, event.date.month);
    _clearSearch();
    setState(() {
      _focusedMonth = eventMonth;
      _selectedDate = DateTime(event.date.year, event.date.month, event.date.day);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showEventDetailSheet(
        context,
        ref,
        event: event,
        focusedMonth: eventMonth,
      );
    });
  }

  void _applyCalendarFocus(CalendarFocusRequest? request) {
    if (request == null) return;

    setState(() {
      _focusedMonth = DateTime(request.month.year, request.month.month);
      _selectedDate = DateTime(
        request.month.year,
        request.month.month,
        request.day,
      );
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
    showEventComposeSheet(context, ref, initialDate: _selectedDate);
  }

  void _showFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Filtrar eventos', style: AppTypography.displaySmall()),
                const SizedBox(height: 12),
                FilterChipRow(
                  selected: _filter,
                  layout: FilterChipLayout.wrap,
                  onSelected: (filter) {
                    Navigator.pop(context);
                    _onFilterChanged(filter);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ForumsBeigeBackground(),
          SafeArea(
            bottom: false,
            child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => CofradeoErrorPanel(
              message: 'No se pudieron cargar los eventos del calendario.',
              subtitle: 'Comprueba tu conexión e inténtalo de nuevo.',
              onRetry: () {
                invalidateCalendarData(ref, _focusedMonth);
                ref.invalidate(eventBookmarkIdsProvider);
              },
            ),
            data: (events) {
              final bookmarkIds =
                  ref.watch(eventBookmarkIdsProvider).value ?? {};
              final dayEvents = applyCalendarEventFilter(
                eventsOnDate(events, _selectedDate),
                _filter,
                bookmarkIds,
              );
              final isSearchActive = _searchQuery.isNotEmpty;

              return RefreshIndicator(
                onRefresh: () async {
                  invalidateCalendarData(ref, _focusedMonth);
                  ref.invalidate(eventBookmarkIdsProvider);
                  await ref.read(calendarEventsProvider(_focusedMonth).future);
                },
                child: _CalendarBody(
                  focusedMonth: _focusedMonth,
                  selectedDate: _selectedDate,
                  filter: _filter,
                  events: events,
                  dayEvents: dayEvents,
                  onDateSelected: _onDateSelected,
                  onFilterChanged: _onFilterChanged,
                  onGoToToday: _goToToday,
                  onOpenMonthCalendar: () => _openMonthCalendar(events),
                  onOpenDayEvents: _openDayEventsSheet,
                  onEventTap: _onEventTap,
                  onBookmarkToggle: _toggleBookmark,
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  searchResults: _searchResults,
                  isSearching: _searching,
                  onSearchChanged: _onSearchChanged,
                  onClearSearch: _clearSearch,
                  onSearchEventTap: _onSearchEventTap,
                  onShowFilterSheet: _showFilterSheet,
                  isSearchActive: isSearchActive,
                ),
              );
            },
          ),
        ),
        ],
      ),
    );
  }
}

class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.focusedMonth,
    required this.selectedDate,
    required this.filter,
    required this.events,
    required this.onDateSelected,
    required this.onFilterChanged,
    required this.onGoToToday,
    required this.onOpenMonthCalendar,
    required this.onOpenDayEvents,
    required this.onEventTap,
    required this.onBookmarkToggle,
    required this.searchController,
    required this.searchQuery,
    required this.searchResults,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSearchEventTap,
    required this.onShowFilterSheet,
    this.dayEvents,
    this.isSearchActive = false,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final EventFilter filter;
  final List<CalendarEvent> events;
  final List<CalendarEvent>? dayEvents;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<EventFilter> onFilterChanged;
  final VoidCallback onGoToToday;
  final VoidCallback onOpenMonthCalendar;
  final ValueChanged<List<CalendarEvent>> onOpenDayEvents;
  final ValueChanged<CalendarEvent> onEventTap;
  final Future<void> Function(CalendarEvent) onBookmarkToggle;
  final TextEditingController searchController;
  final String searchQuery;
  final List<CalendarEvent> searchResults;
  final bool isSearching;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<CalendarEvent> onSearchEventTap;
  final VoidCallback onShowFilterSheet;
  final bool isSearchActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkIds = ref.watch(eventBookmarkIdsProvider).value ?? {};
    final selectedDayEvents = dayEvents ?? const [];
    final listEvents =
        isSearchActive ? const <CalendarEvent>[] : selectedDayEvents;
    final showHero = !isSearchActive && selectedDayEvents.isNotEmpty;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isTodaySelected = isSameCalendarDay(selectedDate, today);
    final eventCountLabel = selectedDayEvents.isEmpty
        ? '0 eventos'
        : '${selectedDayEvents.length} evento${selectedDayEvents.length == 1 ? '' : 's'}';
    final daySectionTitle = formatCalendarDayEventsSectionTitle(selectedDate);
    final monthLabel = formatCalendarMonthLabel(selectedDate);
    final countdown = ref.watch(cofradeCountdownProvider);
    final canManageLibrary = ref.watch(isCalendarEditorProvider);
    final showGoToToday =
        !isCurrentCalendarMonth(focusedMonth) || !isTodaySelected;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            CalendarDesign.screenPadding,
            10,
            CalendarDesign.screenPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'CALENDARIO',
                    style: AppTypography.screenTitle().copyWith(
                      fontSize: CalendarDesign.headerTitleSize,
                      letterSpacing: CalendarDesign.headerLetterSpacing,
                      height: 1,
                    ),
                  ),
                ),
                if (showGoToToday)
                  TextButton(
                    onPressed: onGoToToday,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Hoy',
                      style: AppTypography.bodyMedium(
                        color: AppColors.burgundy,
                      ).copyWith(
                        fontSize: CalendarDesign.linkFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (canManageLibrary)
                  IconButton(
                    onPressed: () => OrganizerPickerSheet.show(
                      context,
                      selectOnTap: false,
                    ),
                    tooltip: 'Biblioteca de escudos',
                    icon: const Icon(
                      Icons.account_balance_outlined,
                      size: 20,
                    ),
                    color: AppColors.textPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                const NotificationsBellButton(
                  iconColor: AppColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
        if (!isSearchActive && countdown != null)
          SliverPadding(
            padding: const EdgeInsets.only(top: 8),
            sliver: SliverToBoxAdapter(
              child: CofradeCountdownBanner(
                countdown: countdown,
              ),
            ),
          ),
        if (showHero)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CalendarDesign.screenPadding,
                10,
                CalendarDesign.screenPadding,
                0,
              ),
              child: CalendarHeroCarousel(
                events: selectedDayEvents,
                onEventTap: onEventTap,
              ),
            ),
          ),
        if (!isSearchActive)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              CalendarDesign.screenPadding,
              10,
              CalendarDesign.screenPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    monthLabel,
                    style: CalendarDesign.sectionTitle(),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpenMonthCalendar,
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.burgundy,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!isSearchActive)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              CalendarDesign.screenPadding,
              4,
              CalendarDesign.screenPadding,
              6,
            ),
            sliver: SliverToBoxAdapter(
              child: CalendarWeekStrip(
                selectedDate: selectedDate,
                events: events,
                filter: filter,
                bookmarkIds: bookmarkIds,
                onDaySelected: onDateSelected,
                onOpenMonthCalendar: onOpenMonthCalendar,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            CalendarDesign.screenPadding,
            4,
            CalendarDesign.screenPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CalendarFilterBar(
                  selected: filter,
                  onOpenFilters: onShowFilterSheet,
                ),
                const SizedBox(height: CalendarDesign.blockGap),
                _CalendarSearchField(
                  controller: searchController,
                  query: searchQuery,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                ),
              ],
            ),
          ),
        ),
        ..._calendarEventsSlivers(
          isSearchActive: isSearchActive,
          daySectionTitle: daySectionTitle,
          eventCountLabel: eventCountLabel,
          selectedDayEvents: selectedDayEvents,
          listEvents: listEvents,
          searchQuery: searchQuery,
          searchResults: searchResults,
          isSearching: isSearching,
          onEventTap: onEventTap,
          onSearchEventTap: onSearchEventTap,
          onClearSearch: onClearSearch,
          bookmarkIds: bookmarkIds,
          onBookmarkToggle: onBookmarkToggle,
          isTodaySelected: isTodaySelected,
          bottomPadding: canManageLibrary ? 12 : 8,
        ),
      ],
    );
  }
}

List<Widget> _calendarEventsSlivers({
  required bool isSearchActive,
  required String daySectionTitle,
  required String eventCountLabel,
  required List<CalendarEvent> selectedDayEvents,
  required List<CalendarEvent> listEvents,
  required String searchQuery,
  required List<CalendarEvent> searchResults,
  required bool isSearching,
  required ValueChanged<CalendarEvent> onEventTap,
  required ValueChanged<CalendarEvent> onSearchEventTap,
  required VoidCallback onClearSearch,
  required Set<String> bookmarkIds,
  required Future<void> Function(CalendarEvent) onBookmarkToggle,
  required bool isTodaySelected,
  required double bottomPadding,
}) {
  final title = Row(
    children: [
      Expanded(
        child: Text(
          isSearchActive ? 'Resultados' : daySectionTitle,
          style: CalendarDesign.sectionTitle(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (!isSearchActive && selectedDayEvents.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.7),
            ),
          ),
          child: Text(
            eventCountLabel,
            style: AppTypography.labelSmall(
              color: AppColors.textSecondary,
            ).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );

  final body = _EventsSectionBody(
    dayEvents: selectedDayEvents,
    listEvents: listEvents,
    isSearchActive: isSearchActive,
    searchQuery: searchQuery,
    searchResults: searchResults,
    isSearching: isSearching,
    onEventTap: onEventTap,
    onSearchEventTap: onSearchEventTap,
    onClearSearch: onClearSearch,
    bookmarkedIds: bookmarkIds,
    onBookmarkToggle: onBookmarkToggle,
    isTodaySelected: isTodaySelected,
  );

  final visibleCount =
      isSearchActive ? searchResults.length : listEvents.length;
  // Con pocos ítems: título pegado al buscador; el aire queda debajo del evento.
  final fillRemaining = !isSearchActive && visibleCount <= 2;

  if (fillRemaining) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            CalendarDesign.screenPadding,
            10,
            CalendarDesign.screenPadding,
            bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 8),
              body,
              const Spacer(),
            ],
          ),
        ),
      ),
    ];
  }

  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        CalendarDesign.screenPadding,
        10,
        CalendarDesign.screenPadding,
        8,
      ),
      sliver: SliverToBoxAdapter(child: title),
    ),
    SliverPadding(
      padding: EdgeInsets.fromLTRB(
        CalendarDesign.screenPadding,
        0,
        CalendarDesign.screenPadding,
        bottomPadding,
      ),
      sliver: SliverToBoxAdapter(child: body),
    ),
  ];
}

class _CalendarFilterBar extends StatelessWidget {
  const _CalendarFilterBar({
    required this.selected,
    required this.onOpenFilters,
  });

  final EventFilter selected;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final isActive = selected != EventFilter.todas;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenFilters,
        borderRadius: BorderRadius.circular(CalendarDesign.chipRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.burgundy : AppColors.surface,
            borderRadius: BorderRadius.circular(CalendarDesign.chipRadius),
            border: Border.all(
              color: isActive
                  ? AppColors.burgundy
                  : AppColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: isActive ? AppColors.textOnDark : AppColors.burgundy,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isActive ? selected.label : 'Todas las categorías',
                  style: AppTypography.bodyMedium(
                    color: isActive
                        ? AppColors.textOnDark
                        : AppColors.textSecondary,
                  ).copyWith(
                    fontSize: CalendarDesign.chipFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.more_horiz,
                size: 20,
                color: isActive ? AppColors.textOnDark : AppColors.burgundy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarSearchField extends StatelessWidget {
  const _CalendarSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CalendarDesign.searchHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyMedium().copyWith(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Buscar eventos...',
          hintStyle: AppTypography.bodyMedium(color: AppColors.textMuted)
              .copyWith(fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: AppColors.goldDark, size: 18),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.burgundy,
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CalendarDesign.searchRadius),
            borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CalendarDesign.searchRadius),
            borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CalendarDesign.searchRadius),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.1),
          ),
        ),
      ),
    );
  }
}

class _EventsSectionBody extends StatelessWidget {
  const _EventsSectionBody({
    required this.dayEvents,
    required this.listEvents,
    required this.isSearchActive,
    required this.searchQuery,
    required this.searchResults,
    required this.isSearching,
    required this.onEventTap,
    required this.onSearchEventTap,
    required this.onClearSearch,
    required this.bookmarkedIds,
    required this.onBookmarkToggle,
    required this.isTodaySelected,
  });

  final List<CalendarEvent> dayEvents;
  final List<CalendarEvent> listEvents;
  final bool isSearchActive;
  final String searchQuery;
  final List<CalendarEvent> searchResults;
  final bool isSearching;
  final ValueChanged<CalendarEvent> onEventTap;
  final ValueChanged<CalendarEvent> onSearchEventTap;
  final VoidCallback onClearSearch;
  final Set<String> bookmarkedIds;
  final Future<void> Function(CalendarEvent) onBookmarkToggle;
  final bool isTodaySelected;

  @override
  Widget build(BuildContext context) {
    if (isSearchActive) {
      if (searchQuery.length < 2) {
        return const _EmptyHint(
          message: 'Escribe al menos 2 letras para buscar eventos.',
        );
      }
      if (isSearching) {
        return const _SearchLoadingCard();
      }
      if (searchResults.isEmpty) {
        return const _EmptyHint(
          message: 'No hay eventos que coincidan con esta búsqueda.',
        );
      }
      return _EventList(
        events: searchResults,
        onEventTap: onSearchEventTap,
        bookmarkedIds: bookmarkedIds,
        onBookmarkToggle: onBookmarkToggle,
      );
    }

    if (listEvents.isEmpty) {
      if (dayEvents.isEmpty) {
        return const _EmptyHint(
          message: 'No hay eventos para este día y filtro.',
        );
      }
      return const SizedBox.shrink();
    }

    return _EventList(
      events: listEvents,
      highlighted: isTodaySelected,
      onEventTap: onEventTap,
      bookmarkedIds: bookmarkedIds,
      onBookmarkToggle: onBookmarkToggle,
    );
  }
}

class _SearchLoadingCard extends StatelessWidget {
  const _SearchLoadingCard();

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('Buscando eventos...', style: AppTypography.bodyMedium()),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.events,
    required this.onEventTap,
    required this.bookmarkedIds,
    required this.onBookmarkToggle,
    this.highlighted = false,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;
  final Set<String> bookmarkedIds;
  final Future<void> Function(CalendarEvent) onBookmarkToggle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: CalendarDesign.eventCardGap),
          EventCard(
            event: events[i],
            highlighted: highlighted,
            isBookmarked: isEventBookmarked(bookmarkedIds, events[i]),
            onBookmarkToggle: events[i].id == null
                ? null
                : () => onBookmarkToggle(events[i]),
            onTap: () => onEventTap(events[i]),
          ),
        ],
      ],
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
