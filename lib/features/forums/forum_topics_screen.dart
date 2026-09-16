import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import '../../core/widgets/cofradeo_bottom_nav.dart';
import '../../shared/models/forum.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/models/calendar_focus_request.dart';
import '../../shared/models/calendar_event.dart';
import '../ads/ads_provider.dart';
import '../ads/models/sponsored_ad.dart';
import '../ads/widgets/sponsored_ad_card.dart';
import '../ads/widgets/sponsored_placement_slot.dart';
import '../auth/auth_provider.dart';
import '../permissions/permissions_provider.dart';
import 'data/forum_pillar_covers.dart';
import 'data/mock_forums.dart';
import 'forums_hero_tokens.dart';
import 'forum_topics_typography.dart';
import 'forums_provider.dart';
import '../profile/profile_provider.dart';
import 'utils/forum_activity_badge.dart';
import 'utils/forum_navigation.dart';
import 'utils/hermandad_board_display.dart';
import 'utils/hermandad_local_assets.dart';
import 'utils/noticias_forum.dart';
import 'utils/topic_list_order.dart';
import 'utils/topic_permissions.dart';
import 'widgets/forum_about_tab.dart';
import 'widgets/forum_pillar_icon_mark.dart';
import 'widgets/noticias_follow_button.dart';
import 'widgets/topic_card.dart';
import 'widgets/topic_compose_sheet.dart';

/// Tras cuántos temas de comunidad se repite el banner en el feed.
const _forumListBannerInterval = 12;

/// Fondo blanco del canal Hermandades (lista a ancho completo).
const _hermandadesCanvas = AppColors.surface;

/// Mínimo de temas para activar repeticiones en el scroll (sin evento patrocinado).
const _forumListBannerMinTopicsForInFeed = 20;

/// Si hay evento patrocinado, el primer banner del feed va tras este número de temas.
const _forumListBannerFirstAfterTopicsWithEvent = 6;

class ForumTopicsScreen extends ConsumerStatefulWidget {
  const ForumTopicsScreen({super.key, required this.forumId});

  final String forumId;

  @override
  ConsumerState<ForumTopicsScreen> createState() => _ForumTopicsScreenState();
}

class _ForumTopicsScreenState extends ConsumerState<ForumTopicsScreen>
    with WidgetsBindingObserver {
  static const _panelOverlap = ForumsHeroTokens.panelOverlapReserve;
  static const _panelRadius = ForumsHeroTokens.panelTopRadius;
  static const _listTopPadding = 2.0;

  final _searchController = TextEditingController();
  var _tabIndex = 0;
  var _sort = TopicListSort.lastActivity;
  var _filter = TopicListFilter.all;
  String? _selectedHermandadesDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.forumId == 'hermandades') {
      HermandadLocalAssets.ensureLoaded(force: true).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(forumTopicsProvider(widget.forumId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final forumId = widget.forumId;
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final isSuspended = ref.watch(isCurrentUserSuspendedProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final moderatedForumIds =
        ref.watch(moderatedForumIdsProvider).asData?.value ?? const <String>{};
    final canCreateTopic = !isSuspended &&
        canCreateTopicInForum(
          forumId: forumId,
          isAdmin: isAdmin,
          moderatedForumIds: moderatedForumIds,
        );
    final forum =
        ref.watch(forumPillarProvider(forumId)).asData?.value ??
        (supabaseReady ? null : forumById(forumId));
    final topicsAsync = ref.watch(forumTopicsProvider(forumId));

    if (supabaseReady) {
      ref.watch(forumTopicsRealtimeProvider(forumId));
    }

    if (forum == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foro')),
        body: const Center(child: Text('Foro no encontrado')),
      );
    }

    if (forum.isLocked) {
      return _LockedForumView(
        forum: forum,
        onBack: () => popForumTopicsList(context),
      );
    }

    return Scaffold(
      backgroundColor: forumId == 'hermandades'
          ? _hermandadesCanvas
          : AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accentRed,
        onRefresh: () async {
          ref.invalidate(forumTopicsProvider(forumId));
          ref.invalidate(forumPillarProvider(forumId));
          await ref.read(forumTopicsProvider(forumId).future);
        },
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ForumDetailHero(
                  forum: forum,
                  onBack: () => popForumTopicsList(context),
                ),
                Transform.translate(
                  offset: const Offset(0, -_panelOverlap),
                  child: Material(
                    elevation: 10,
                    shadowColor: Colors.black.withValues(alpha: 0.14),
                    color: forumId == 'hermandades'
                        ? _hermandadesCanvas
                        : AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_panelRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _ForumDetailPanel(
                      forum: forum,
                      tabIndex: _tabIndex,
                      onTabChanged: (index) => setState(() => _tabIndex = index),
                      searchController: _searchController,
                      onSearchChanged: (_) => setState(() {}),
                      sort: _sort,
                      onSortChanged: (value) => setState(() => _sort = value),
                      filter: _filter,
                      onFilterTap: () => _showFilterSheet(context),
                      showNewTopic: canCreateTopic,
                      newTopicLabel: isNoticiasForum(forumId)
                          ? 'Nueva noticia'
                          : 'Nuevo tema',
                      onNewTopic: () =>
                          showTopicComposeSheet(context, ref, forumId: forumId),
                      hermandadesDayFilter: forumId == 'hermandades'
                          ? _HermandadesDayChips(
                              days: _hermandadesDayOrder,
                              selectedDay: _selectedHermandadesDay,
                              onSelected: (day) {
                                setState(() => _selectedHermandadesDay = day);
                              },
                            )
                          : null,
                      selectedHermandadesDay: forumId == 'hermandades'
                          ? _selectedHermandadesDay
                          : null,
                      onHermandadesDaySelected: forumId == 'hermandades'
                          ? (day) =>
                              setState(() => _selectedHermandadesDay = day)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_tabIndex == 0)
            ..._buildTopicsSlivers(
              context,
              ref,
              forum: forum,
              topicsAsync: topicsAsync,
              supabaseReady: supabaseReady,
            ),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildTopicsSlivers(
    BuildContext context,
    WidgetRef ref, {
    required ForumCategory forum,
    required AsyncValue<List<ForumTopic>> topicsAsync,
    required bool supabaseReady,
  }) {
    if (supabaseReady) {
      return topicsAsync.when(
        loading: () => [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
        error: (_, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar los temas.',
                style: ForumTopicsTypography.style(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        data: (topics) => _topicsSlivers(context, ref, topics: topics),
      );
    }

    return _topicsSlivers(
      context,
      ref,
      topics: topicsForForum(widget.forumId),
    );
  }

  List<Widget> _topicsSlivers(
    BuildContext context,
    WidgetRef ref, {
    required List<ForumTopic> topics,
  }) {
    final forumId = widget.forumId;
    final query = _searchController.text;
    final visibleTopics = forumId == 'hermandades'
        ? topics
        : topics.where((t) => !isSeasonCommunityTopic(t)).toList();
    var dayFiltered = forumId == 'hermandades'
        ? _filterTopicsBySelectedDay(_orderedTopics(visibleTopics))
        : visibleTopics;
    final processed = sortForumTopics(
      filterForumTopics(
        dayFiltered,
        query: query,
        filter: _filter,
      ),
      _sort,
    );

    final listBannerPlacement = _listBannerPlacement(forumId);
    final showInFeedBanners = _showInFeedListBanners(query);
    final hasSponsoredEvent = _hasSponsoredEventContext(ref, forumId);
    final showTopListBanner = !hasSponsoredEvent;

    final listTop = forumId == 'hermandades' ? 0.0 : _listTopPadding;

    if (processed.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            listTop,
            16,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              query.isEmpty && _filter == TopicListFilter.all
                  ? 'Aún no hay temas en este foro.'
                  : 'No hay temas que coincidan con tu búsqueda.',
              style: ForumTopicsTypography.style(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _ForumTopicsSponsoredEventSlot(forumId: forumId),
          ),
        ),
        if (showTopListBanner)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              cofradeoBottomScrollPadding(context),
            ),
            sliver: SliverToBoxAdapter(
              child: _ForumTopicsListBanner(
                placement: listBannerPlacement,
                forumId: forumId,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(bottom: cofradeoBottomScrollPadding(context)),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
      ];
    }

    final split = splitForumTopics(processed);
    final slivers = <Widget>[];

    if (split.pinned.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, listTop, 16, 0),
          sliver: SliverList.separated(
            itemCount: split.pinned.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildTopicCard(
              context,
              ref,
              split.pinned[index],
              pinned: true,
            ),
          ),
        ),
      );
    }

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: _ForumTopicsSponsoredEventSlot(forumId: forumId),
        ),
      ),
    );

    if (showTopListBanner) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: _ForumTopicsListBanner(
              placement: listBannerPlacement,
              forumId: forumId,
              dense: true,
            ),
          ),
        ),
      );
    }

    if (split.community.isNotEmpty) {
      final rows = _communityRows(
        community: split.community,
        listBannerPlacement: listBannerPlacement,
        forumId: forumId,
        showInFeedBanners: showInFeedBanners,
        hasSponsoredEvent: hasSponsoredEvent,
      );
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            forumId == 'hermandades'
                ? 0
                : (split.pinned.isEmpty ? listTop : 6),
            16,
            0,
          ),
          sliver: SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildCommunityRow(context, ref, rows[index]),
          ),
        ),
      );
    }

    slivers.add(
      SliverPadding(
        padding: EdgeInsets.only(bottom: cofradeoBottomScrollPadding(context)),
        sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
    );

    return slivers;
  }

  AdPlacement _listBannerPlacement(String forumId) {
    return forumId == 'hermandades'
        ? AdPlacement.hermandades
        : AdPlacement.forumsMiddle;
  }

  bool _hasSponsoredEventContext(WidgetRef ref, String forumId) {
    final adAsync = ref.watch(
      adForPlacementProvider(
        AdPlacementQuery(
          placement: AdPlacement.forumsEvent,
          forumId: forumId,
        ),
      ),
    );

    return adAsync.when(
      data: (ad) {
        if (ad == null) return false;
        final eventId = ad.calendarEventId?.trim();
        if (eventId == null || eventId.isEmpty) return false;

        return ref.watch(calendarEventByIdProvider(eventId)).when(
          data: (event) => event != null,
          loading: () => true,
          error: (_, _) => false,
        );
      },
      loading: () => true,
      error: (_, _) => false,
    );
  }

  bool _showInFeedListBanners(String query) {
    return query.trim().isEmpty && _filter == TopicListFilter.all;
  }

  bool _shouldInsertInFeedBanner({
    required int topicsRendered,
    required int totalTopics,
    required bool showInFeedBanners,
    required bool hasSponsoredEvent,
  }) {
    if (!showInFeedBanners) return false;

    if (hasSponsoredEvent) {
      if (topicsRendered == _forumListBannerFirstAfterTopicsWithEvent) {
        return true;
      }
      if (topicsRendered > _forumListBannerFirstAfterTopicsWithEvent &&
          (topicsRendered - _forumListBannerFirstAfterTopicsWithEvent) %
                  _forumListBannerInterval ==
              0) {
        return true;
      }
      return false;
    }

    if (totalTopics < _forumListBannerMinTopicsForInFeed) return false;
    return topicsRendered % _forumListBannerInterval == 0;
  }

  List<_ForumTopicRow> _communityRows({
    required List<ForumTopic> community,
    required AdPlacement listBannerPlacement,
    required String forumId,
    required bool showInFeedBanners,
    required bool hasSponsoredEvent,
  }) {
    final rows = <_ForumTopicRow>[];
    var topicCount = 0;

    for (final entry in _topicEntries(community)) {
      final dayLabel = entry.dayLabel;
      if (dayLabel != null) {
        rows.add(_ForumTopicRow.day(dayLabel));
        continue;
      }

      final topic = entry.topic!;
      rows.add(_ForumTopicRow.topic(topic));
      topicCount++;
      if (_shouldInsertInFeedBanner(
        topicsRendered: topicCount,
        totalTopics: community.length,
        showInFeedBanners: showInFeedBanners,
        hasSponsoredEvent: hasSponsoredEvent,
      )) {
        rows.add(
          _ForumTopicRow.listBanner(
            placement: listBannerPlacement,
            forumId: forumId,
          ),
        );
      }
    }

    return rows;
  }

  Widget _buildCommunityRow(
    BuildContext context,
    WidgetRef ref,
    _ForumTopicRow row,
  ) {
    return switch (row.kind) {
      _ForumTopicRowKind.dayHeader => _HermandadesDayHeader(label: row.dayLabel!),
      _ForumTopicRowKind.topic =>
        _buildTopicCard(context, ref, row.topic!, pinned: row.pinned),
      _ForumTopicRowKind.listBanner => _ForumTopicsListBanner(
          placement: row.placement!,
          forumId: row.forumId!,
          dense: true,
        ),
    };
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<TopicListFilter>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar temas',
                  style: ForumTopicsTypography.sectionLabel(),
                ),
                const SizedBox(height: 14),
                for (final option in TopicListFilter.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _filter == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _filter == option
                          ? AppColors.burgundy
                          : AppColors.textMuted,
                    ),
                    title: Text(
                      option.label,
                      style: ForumTopicsTypography.style(),
                    ),
                    onTap: () => Navigator.pop(ctx, option),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && selected != _filter) {
      setState(() => _filter = selected);
    }
  }

  Widget _buildTopicCard(
    BuildContext context,
    WidgetRef ref,
    ForumTopic topic, {
    bool pinned = false,
  }) {
    return TopicCard(
      topic: topic,
      pinned: pinned || topic.isPinned,
      variant: TopicCardVariant.premium,
      forumId: widget.forumId,
      onTap: () async {
        await context.push('/foros/${widget.forumId}/tema/${topic.id}');
        if (context.mounted) {
          ref.invalidate(forumTopicsProvider(widget.forumId));
        }
      },
    );
  }

  List<_TopicListEntry> _topicEntries(List<ForumTopic> topics) {
    if (widget.forumId != 'hermandades') {
      return [for (final topic in topics) _TopicListEntry.topic(topic)];
    }

    // Con un día concreto seleccionado no hace falta cabecera de grupo.
    if (_selectedHermandadesDay != null) {
      return [for (final topic in topics) _TopicListEntry.topic(topic)];
    }

    final entries = <_TopicListEntry>[];
    String? currentDay;
    for (final topic in topics) {
      final day = _dayFromHermandadTitle(topic.title);
      if (day != null && day != currentDay) {
        entries.add(_TopicListEntry.day(day));
        currentDay = day;
      }
      entries.add(_TopicListEntry.topic(topic));
    }
    return entries;
  }

  String? _dayFromHermandadTitle(String title) {
    final parts = title.split(' · ');
    if (parts.length < 2) return null;
    return parts.first.trim();
  }

  List<ForumTopic> _filterTopicsBySelectedDay(List<ForumTopic> topics) {
    final selected = _selectedHermandadesDay;
    if (widget.forumId != 'hermandades' || selected == null) return topics;
    return [
      for (final topic in topics)
        if (_dayFromHermandadTitle(topic.title) == selected) topic,
    ];
  }

  List<ForumTopic> _orderedTopics(List<ForumTopic> topics) {
    if (widget.forumId != 'hermandades') return topics;
    return [...topics]..sort((a, b) {
      final aDay = _dayFromHermandadTitle(a.title);
      final bDay = _dayFromHermandadTitle(b.title);
      final aIndex = _hermandadesDayOrder.indexOf(aDay ?? '');
      final bIndex = _hermandadesDayOrder.indexOf(bDay ?? '');
      final safeA = aIndex == -1 ? _hermandadesDayOrder.length : aIndex;
      final safeB = bIndex == -1 ? _hermandadesDayOrder.length : bIndex;
      if (safeA != safeB) return safeA.compareTo(safeB);
      return topics.indexOf(a).compareTo(topics.indexOf(b));
    });
  }
}

void _openSponsoredCalendarEvent(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
) {
  ref.read(calendarFocusRequestProvider.notifier).setFocus(
        CalendarFocusRequest(
          month: DateTime(event.date.year, event.date.month),
          day: event.date.day,
          event: event,
        ),
      );
  context.go('/calendario');
}

class _ForumDetailHero extends StatelessWidget {
  const _ForumDetailHero({
    required this.forum,
    required this.onBack,
  });

  final ForumCategory forum;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cover = forumPillarCover(forum);
    final activity = forumActivityLevel(forum);
    final isHermandades = forum.isHermandadesChannel;
    final isNoticias = isNoticiasForum(forum.id);
    final screenW = MediaQuery.sizeOf(context).width;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: ForumPillarCoverImage(
              cover: cover,
              fit: BoxFit.cover,
              alignment: cover.alignment,
              filterQuality: FilterQuality.medium,
              // Decode más ancho para que el cover a pantalla completa no se vea pixelado.
              cacheSize: screenW * 1.35,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isHermandades
                    ? _hermandadesHeroGradient()
                    : isNoticias
                        ? _noticiasHeroGradient()
                        : ForumsHeroTokens.gradientOverlay(),
              ),
            ),
          ),
          if (isNoticias)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.22),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                    stops: const [0.0, 0.18, 0.82, 1.0],
                  ),
                ),
              ),
            ),
          if (isHermandades)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.burgundyDark.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: ForumsHeroTokens.detailHeroPadding(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IconButton(
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    alignment: Alignment.center,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.gold,
                      size: 28,
                    ),
                    tooltip: 'Volver',
                  ),
                ),
                const SizedBox(width: 2),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ForumHeroMedallion(
                      forum: forum,
                      size: isHermandades ? 52 : 44,
                    ),
                    const SizedBox(height: 6),
                    ForumActivityBadge(level: activity, compact: true),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHermandades) ...[
                        Text(
                          'CANAL OFICIAL',
                          style: ForumTopicsTypography.onDark(
                            color: AppColors.goldPale,
                            fontWeight: FontWeight.w600,
                          ).copyWith(
                            fontSize: 9,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        forum.name.toUpperCase(),
                        style: isHermandades
                            ? AppTypography.displaySmall(
                                color: AppColors.gold,
                              ).copyWith(
                                fontSize: 20,
                                letterSpacing: 1.0,
                                height: 1.05,
                                fontWeight: FontWeight.w600,
                              )
                            : ForumTopicsTypography.heroTitle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isHermandades) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: 36,
                          height: 1.5,
                          color: AppColors.gold.withValues(alpha: 0.85),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        forum.description,
                        style: isHermandades
                            ? ForumsHeroTokens.detailHeroDescriptionStyle()
                                .copyWith(fontSize: 12, height: 1.35)
                            : ForumsHeroTokens.detailHeroDescriptionStyle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      _ForumHeroStatsRow(forum: forum),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

LinearGradient _noticiasHeroGradient() => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.18),
        Colors.black.withValues(alpha: 0.42),
        Colors.black.withValues(alpha: 0.72),
        Colors.black.withValues(alpha: 0.88),
      ],
      stops: const [0.0, 0.38, 0.72, 1.0],
    );

LinearGradient _hermandadesHeroGradient() => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.22),
        Colors.black.withValues(alpha: 0.45),
        AppColors.burgundyDark.withValues(alpha: 0.72),
        Colors.black.withValues(alpha: 0.88),
      ],
      stops: const [0.0, 0.35, 0.72, 1.0],
    );

class _ForumHeroMedallion extends StatelessWidget {
  const _ForumHeroMedallion({required this.forum, required this.size});

  final ForumCategory forum;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child = isNoticiasForum(forum.id)
        ? ClipOval(
            child: Image.asset(
              AppAssets.forumNoticiasIcon,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              cacheWidth: ImageDecodeCache.px(context, size),
              cacheHeight: ImageDecodeCache.px(context, size),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  ForumPillarIconMark(forum: forum, size: size),
            ),
          )
        : ForumPillarIconMark(forum: forum, size: size);

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // En Noticias el aro blanco del medallón se veía como “borde sucio”
          // sobre la foto oscura; usamos aro burdeos suave.
          border: Border.all(
            color: isNoticiasForum(forum.id)
                ? AppColors.burgundyDark.withValues(alpha: 0.85)
                : AppColors.surface,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _ForumHeroStatsRow extends StatelessWidget {
  const _ForumHeroStatsRow({required this.forum});

  final ForumCategory forum;

  @override
  Widget build(BuildContext context) {
    final style = ForumTopicsTypography.onDark(
      color: Colors.white.withValues(alpha: 0.86),
    );

    return Row(
      children: [
        const Icon(
          Icons.folder_outlined,
          size: 11,
          color: AppColors.goldPale,
        ),
        const SizedBox(width: 3),
        Text('${formatCount(forum.topicCount)} temas', style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: 1,
            height: 9,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        const Icon(
          Icons.chat_bubble_outline,
          size: 11,
          color: AppColors.goldPale,
        ),
        const SizedBox(width: 3),
        Text('${formatCount(forum.messageCount)} respuestas', style: style),
      ],
    );
  }
}

class ForumActivityBadge extends StatelessWidget {
  const ForumActivityBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  final ForumActivityLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (border, fg, dot) = switch (level) {
      ForumActivityLevel.veryActive => (
        AppColors.gold.withValues(alpha: 0.55),
        AppColors.goldPale,
        AppColors.gold,
      ),
      ForumActivityLevel.active => (
        Colors.white.withValues(alpha: 0.28),
        Colors.white,
        const Color(0xFF6BCB77),
      ),
      ForumActivityLevel.low => (
        Colors.white.withValues(alpha: 0.22),
        Colors.white70,
        AppColors.textMuted,
      ),
      ForumActivityLevel.upcoming => (
        Colors.white.withValues(alpha: 0.22),
        Colors.white70,
        null,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            forumActivityLabel(level),
            style: ForumTopicsTypography.onDark(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumDetailPanel extends StatelessWidget {
  const _ForumDetailPanel({
    required this.forum,
    required this.tabIndex,
    required this.onTabChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.sort,
    required this.onSortChanged,
    required this.filter,
    required this.onFilterTap,
    required this.showNewTopic,
    required this.newTopicLabel,
    required this.onNewTopic,
    this.hermandadesDayFilter,
    this.selectedHermandadesDay,
    this.onHermandadesDaySelected,
  });

  final ForumCategory forum;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final TopicListSort sort;
  final ValueChanged<TopicListSort> onSortChanged;
  final TopicListFilter filter;
  final VoidCallback onFilterTap;
  final bool showNewTopic;
  final String newTopicLabel;
  final VoidCallback onNewTopic;
  final Widget? hermandadesDayFilter;
  final String? selectedHermandadesDay;
  final ValueChanged<String?>? onHermandadesDaySelected;

  @override
  Widget build(BuildContext context) {
    final isHermandades = forum.isHermandadesChannel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _ForumDetailTabs(
          forum: forum,
          tabIndex: tabIndex,
          onTabChanged: onTabChanged,
        ),
        if (tabIndex == 0) ...[
          if (hermandadesDayFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              child: hermandadesDayFilter,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, isHermandades ? 8 : 10, 16, 0),
            child: isHermandades
                ? _HermandadesToolbar(
                    searchController: searchController,
                    onSearchChanged: onSearchChanged,
                    sort: sort,
                    onSortChanged: onSortChanged,
                    selectedDay: selectedHermandadesDay,
                    onDaySelected: onHermandadesDaySelected,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: searchController,
                            onChanged: onSearchChanged,
                            style: ForumTopicsTypography.style(),
                            decoration: InputDecoration(
                              hintText: 'Buscar en este foro...',
                              hintStyle: ForumTopicsTypography.style(
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: AppColors.backgroundElevated,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterIconButton(
                        active: filter != TopicListFilter.all,
                        onTap: onFilterTap,
                      ),
                    ],
                  ),
          ),
          if (!isHermandades)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _SortSelector(
                      sort: sort,
                      onChanged: onSortChanged,
                    ),
                  ),
                  if (showNewTopic) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onNewTopic,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: AppColors.textOnDark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        newTopicLabel,
                        style: ForumTopicsTypography.style(
                          color: AppColors.textOnDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (isNoticiasForum(forum.id))
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: NoticiasFollowButton(),
            ),
        ] else
          ForumAboutTab(forum: forum),
        ],
    );
  }
}

class _HermandadesToolbar extends StatelessWidget {
  const _HermandadesToolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.sort,
    required this.onSortChanged,
    required this.selectedDay,
    this.onDaySelected,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final TopicListSort sort;
  final ValueChanged<TopicListSort> onSortChanged;
  final String? selectedDay;
  final ValueChanged<String?>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.95)),
            ),
            child: SizedBox(
              height: 42,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      textAlignVertical: TextAlignVertical.center,
                      style: ForumTopicsTypography.style().copyWith(
                        fontSize: 13,
                        height: 1,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar hermandad...',
                        hintStyle: ForumTopicsTypography.style(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 13, height: 1),
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.95)),
          ),
          child: InkWell(
            onTap: () => _showHermandadesFilterSheet(context),
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showHermandadesFilterSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Día de estación',
                    style: ForumTopicsTypography.sectionLabel(),
                  ),
                ),
                ListTile(
                  title: Text(
                    'Todas las hermandades',
                    style: ForumTopicsTypography.style(
                      fontWeight: selectedDay == null
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selectedDay == null
                          ? AppColors.burgundy
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: selectedDay == null
                      ? const Icon(Icons.check, color: AppColors.burgundy)
                      : null,
                  onTap: () {
                    onDaySelected?.call(null);
                    Navigator.pop(ctx);
                  },
                ),
                for (final day in _hermandadesDayOrder)
                  ListTile(
                    title: Text(
                      day,
                      style: ForumTopicsTypography.style(
                        fontWeight: selectedDay == day
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selectedDay == day
                            ? AppColors.burgundy
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: selectedDay == day
                        ? const Icon(Icons.check, color: AppColors.burgundy)
                        : null,
                    onTap: () {
                      onDaySelected?.call(day);
                      Navigator.pop(ctx);
                    },
                  ),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Ordenar por',
                    style: ForumTopicsTypography.sectionLabel(),
                  ),
                ),
                for (final option in TopicListSort.values)
                  ListTile(
                    title: Text(
                      option.label,
                      style: ForumTopicsTypography.style(
                        fontWeight: sort == option
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: sort == option
                            ? AppColors.burgundy
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: sort == option
                        ? const Icon(Icons.check, color: AppColors.burgundy)
                        : null,
                    onTap: () {
                      onSortChanged(option);
                      Navigator.pop(ctx);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ForumDetailTabs extends StatelessWidget {
  const _ForumDetailTabs({
    required this.forum,
    required this.tabIndex,
    required this.onTabChanged,
  });

  final ForumCategory forum;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final isHermandades = forum.isHermandadesChannel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _ForumTab(
              label: isHermandades ? 'Publicaciones' : 'Temas de discusión',
              icon: isHermandades
                  ? Icons.newspaper_outlined
                  : Icons.article_outlined,
              selected: tabIndex == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ForumTab(
              label: isHermandades ? 'Acerca del apartado' : 'Acerca del foro',
              icon: Icons.info_outline,
              selected: tabIndex == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumTab extends StatelessWidget {
  const _ForumTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.burgundy : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: ForumTopicsTypography.style(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: selected ? AppColors.burgundy : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.burgundy.withValues(alpha: 0.08)
          : AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.burgundy : AppColors.border,
            ),
          ),
          child: Icon(
            Icons.tune,
            size: 18,
            color: active ? AppColors.burgundy : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _SortSelector extends StatelessWidget {
  const _SortSelector({
    required this.sort,
    required this.onChanged,
  });

  final TopicListSort sort;
  final ValueChanged<TopicListSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _showSortSheet(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text(
                'Ordenar por:',
                style: ForumTopicsTypography.style(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  sort.label,
                  style: ForumTopicsTypography.style(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.burgundy,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSortSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<TopicListSort>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordenar temas',
                  style: ForumTopicsTypography.sectionLabel(),
                ),
                const SizedBox(height: 14),
                for (final option in TopicListSort.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      sort == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: sort == option
                          ? AppColors.burgundy
                          : AppColors.textMuted,
                    ),
                    title: Text(
                      option.label,
                      style: ForumTopicsTypography.style(),
                    ),
                    onTap: () => Navigator.pop(ctx, option),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) onChanged(selected);
  }
}

class _LockedForumView extends StatelessWidget {
  const _LockedForumView({
    required this.forum,
    required this.onBack,
  });

  final ForumCategory forum;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(
          forum.name,
          style: ForumTopicsTypography.style(fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 48, color: AppColors.burgundy),
              const SizedBox(height: 16),
              Text(
                forum.name,
                style: ForumTopicsTypography.style(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                forum.lockedLabel ??
                    'Este foro estará disponible próximamente.',
                style: ForumTopicsTypography.style(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _hermandadesDayOrder = [
  'Viernes de Dolores',
  'Sábado de Pasión',
  'Domingo de Ramos',
  'Lunes Santo',
  'Martes Santo',
  'Miércoles Santo',
  'Jueves Santo',
  'Madrugá',
  'Viernes Santo',
  'Sábado Santo',
  'Domingo de Resurrección',
];

class _HermandadesDayChips extends StatelessWidget {
  const _HermandadesDayChips({
    required this.days,
    required this.selectedDay,
    required this.onSelected,
  });

  final List<String> days;
  final String? selectedDay;
  final ValueChanged<String?> onSelected;

  static const _tileWidth = 66.0;
  static const _stripHeight = 58.0;
  static const _selectedRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        height: _stripHeight,
        width: double.infinity,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final parts = hermandadDayChipParts(day);
            final selected = selectedDay == day;
            final showDivider = index < days.length - 1 &&
                selectedDay != day &&
                selectedDay != days[index + 1];

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HermandadDayStripTile(
                  width: day == 'Domingo de Resurrección' ? 88 : _tileWidth,
                  weekday: parts.weekday,
                  label: parts.label,
                  selected: selected,
                  onTap: () => onSelected(selected ? null : day),
                ),
                if (showDivider)
                  Container(
                    width: 1,
                    height: 20,
                    color: AppColors.border.withValues(alpha: 0.75),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HermandadDayStripTile extends StatelessWidget {
  const _HermandadDayStripTile({
    required this.width,
    required this.weekday,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String weekday;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekdayColor = selected
        ? AppColors.goldPale
        : AppColors.textMuted;
    final labelColor =
        selected ? AppColors.textOnDark : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(_HermandadesDayChips._selectedRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.burgundy : Colors.transparent,
            borderRadius:
                BorderRadius.circular(_HermandadesDayChips._selectedRadius),
            border: selected
                ? Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    width: 1,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.burgundy.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday.toUpperCase(),
                style: ForumTopicsTypography.style(
                  color: weekdayColor,
                  fontWeight: FontWeight.w600,
                ).copyWith(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  height: 1.1,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: ForumTopicsTypography.style(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ).copyWith(fontSize: 12.5, height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicListEntry {
  const _TopicListEntry._({this.dayLabel, this.topic});

  const _TopicListEntry.day(String label) : this._(dayLabel: label);

  const _TopicListEntry.topic(ForumTopic topic) : this._(topic: topic);

  final String? dayLabel;
  final ForumTopic? topic;
}

enum _ForumTopicRowKind { dayHeader, topic, listBanner }

class _ForumTopicRow {
  const _ForumTopicRow._({
    required this.kind,
    this.dayLabel,
    this.topic,
    this.pinned = false,
    this.placement,
    this.forumId,
  });

  const _ForumTopicRow.day(String label)
      : this._(kind: _ForumTopicRowKind.dayHeader, dayLabel: label);

  const _ForumTopicRow.topic(ForumTopic topic, {bool pinned = false})
      : this._(kind: _ForumTopicRowKind.topic, topic: topic, pinned: pinned);

  const _ForumTopicRow.listBanner({
    required AdPlacement placement,
    required String forumId,
  }) : this._(
          kind: _ForumTopicRowKind.listBanner,
          placement: placement,
          forumId: forumId,
        );

  final _ForumTopicRowKind kind;
  final String? dayLabel;
  final ForumTopic? topic;
  final bool pinned;
  final AdPlacement? placement;
  final String? forumId;
}

class _HermandadesDayHeader extends StatelessWidget {
  const _HermandadesDayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = hermandadDayAccentColor(label);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.displaySmall(
                color: AppColors.textPrimary,
              ).copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 1,
            color: AppColors.gold.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de evento patrocinado (calendario), tras temas fijados.
class _ForumTopicsSponsoredEventSlot extends ConsumerWidget {
  const _ForumTopicsSponsoredEventSlot({required this.forumId});

  final String forumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adAsync = ref.watch(
      adForPlacementProvider(
        AdPlacementQuery(
          placement: AdPlacement.forumsEvent,
          forumId: forumId,
        ),
      ),
    );

    return adAsync.when(
      data: (ad) {
        if (ad == null) return const SizedBox.shrink();

        final eventId = ad.calendarEventId?.trim();
        if (eventId == null || eventId.isEmpty) {
          return const SizedBox.shrink();
        }

        final eventAsync = ref.watch(calendarEventByIdProvider(eventId));
        return eventAsync.when(
          data: (event) {
            if (event == null) return const SizedBox.shrink();

            return SponsoredAdCard(
              ad: ad,
              style: SponsoredAdCardStyle.event,
              event: event,
              onEventTap: (linkedEvent) =>
                  _openSponsoredCalendarEvent(context, ref, linkedEvent),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Banner de listado (forums_middle / hermandades): arriba del feed o cada N temas.
class _ForumTopicsListBanner extends StatelessWidget {
  const _ForumTopicsListBanner({
    required this.placement,
    required this.forumId,
    this.dense = false,
  });

  final AdPlacement placement;
  final String forumId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final targetForumId =
        placement == AdPlacement.forumsMiddle ? forumId : null;

    return Padding(
      padding: EdgeInsets.only(top: dense ? 4 : 0),
      child: SponsoredPlacementSlot(
        placement: placement,
        forumId: targetForumId,
        style: SponsoredAdCardStyle.banner,
        compact: true,
      ),
    );
  }
}
