import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/calendar_event.dart';
import 'calendar_design_tokens.dart';
import 'event_bookmarks_provider.dart';
import 'utils/calendar_event_utils.dart';
import 'widgets/event_card.dart';
import 'widgets/event_detail_sheet.dart';

class SavedEventsScreen extends ConsumerWidget {
  const SavedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(bookmarkedEventsProvider);
    final bookmarkIds = ref.watch(eventBookmarkIdsProvider).value ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'EVENTOS GUARDADOS',
            maxLines: 1,
            softWrap: false,
            style: AppTypography.screenAppBarTitle().copyWith(
              fontSize: 22,
              letterSpacing: 0.35,
            ),
          ),
        ),
        centerTitle: true,
        titleSpacing: 0,
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar tus eventos guardados.',
              style: AppTypography.bodyMedium(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const _SavedEventsEmptyState();
          }

          final upcoming = <CalendarEvent>[];
          final past = <CalendarEvent>[];
          for (final event in events) {
            if (isCalendarEventPast(event)) {
              past.add(event);
            } else {
              upcoming.add(event);
            }
          }
          upcoming.sort(compareCalendarEventsByStart);
          past.sort((a, b) => compareCalendarEventsByStart(b, a));

          final upcomingDays = groupCalendarEventsByDay(upcoming);
          final pastDays = groupCalendarEventsByDay(past);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _SavedSummaryBar(
                  total: events.length,
                  upcoming: upcoming.length,
                  past: past.length,
                ),
              ),
              if (upcomingDays.isNotEmpty) ...[
                const _SavedSectionHeader(
                  title: 'Próximos',
                  accent: AppColors.burgundy,
                ),
                ..._dayGroupSlivers(
                  context,
                  ref,
                  groups: upcomingDays,
                  bookmarkIds: bookmarkIds,
                ),
              ],
              if (pastDays.isNotEmpty) ...[
                _SavedSectionHeader(
                  title: 'Anteriores',
                  accent: AppColors.textMuted,
                  topGap: upcomingDays.isEmpty ? 4 : 18,
                ),
                ..._dayGroupSlivers(
                  context,
                  ref,
                  groups: pastDays,
                  bookmarkIds: bookmarkIds,
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _dayGroupSlivers(
    BuildContext context,
    WidgetRef ref, {
    required List<({DateTime day, List<CalendarEvent> events})> groups,
    required Set<String> bookmarkIds,
  }) {
    final slivers = <Widget>[];
    for (final group in groups) {
      slivers.add(
        SliverToBoxAdapter(
          child: _SavedDayLabel(label: formatSavedEventDayLabel(group.day)),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          sliver: SliverList.separated(
            itemCount: group.events.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: CalendarDesign.eventCardGap),
            itemBuilder: (context, index) {
              final event = group.events[index];
              return EventCard(
                event: event,
                isBookmarked: isEventBookmarked(bookmarkIds, event),
                onBookmarkToggle: event.id == null
                    ? null
                    : () => _toggleBookmark(context, ref, event),
                onTap: () => showEventDetailSheet(
                  context,
                  ref,
                  event: event,
                  focusedMonth: DateTime(event.date.year, event.date.month),
                ),
              );
            },
          ),
        ),
      );
    }
    return slivers;
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    try {
      final added =
          await ref.read(eventBookmarkIdsProvider.notifier).toggle(event);
      if (!context.mounted || added == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Evento guardado' : 'Quitado de guardados',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el guardado')),
      );
    }
  }
}

class _SavedEventsEmptyState extends StatelessWidget {
  const _SavedEventsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nada guardado aún',
            style: AppTypography.displaySmall().copyWith(
              fontSize: 22,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pulsa el marcador en un evento del calendario para '
            'tenerlo aquí a mano.',
            style: AppTypography.bodyMedium(
              color: AppColors.textMuted,
            ).copyWith(fontSize: 14.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SavedSummaryBar extends StatelessWidget {
  const _SavedSummaryBar({
    required this.total,
    required this.upcoming,
    required this.past,
  });

  final int total;
  final int upcoming;
  final int past;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (upcoming > 0)
        upcoming == 1 ? '1 próximo' : '$upcoming próximos',
      if (past > 0) past == 1 ? '1 anterior' : '$past anteriores',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.goldDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 1 ? '1 evento guardado' : '$total eventos guardados',
                    style: AppTypography.titleLarge(
                      color: AppColors.burgundy,
                    ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      parts.join(' · '),
                      style: AppTypography.labelSmall(
                        color: AppColors.textMuted,
                      ).copyWith(fontSize: 11.5, letterSpacing: 0.15),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.bookmark_rounded,
              size: 18,
              color: AppColors.goldDark.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedSectionHeader extends StatelessWidget {
  const _SavedSectionHeader({
    required this.title,
    required this.accent,
    this.topGap = 4,
  });

  final String title;
  final Color accent;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topGap, 20, 6),
        child: Text(
          title.toUpperCase(),
          style: AppTypography.labelSmall(color: accent).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.15,
          ),
        ),
      ),
    );
  }
}

class _SavedDayLabel extends StatelessWidget {
  const _SavedDayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Text(
        label,
        style: CalendarDesign.sectionTitle(color: AppColors.textPrimary)
            .copyWith(fontSize: 15, letterSpacing: 0.15),
      ),
    );
  }
}
