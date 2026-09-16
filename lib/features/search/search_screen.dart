import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/calendar_quick_access_button.dart';
import '../auth/auth_provider.dart';
import '../auth/email_verification_gate.dart';
import '../ads/models/sponsored_ad.dart';
import '../ads/widgets/sponsored_placement_slot.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/models/calendar_focus_request.dart';
import '../calendar/widgets/event_card.dart';
import '../forums/widgets/forums_beige_background.dart';
import '../forums/widgets/topic_card.dart';
import 'data/follows_repository.dart';
import 'data/mock_search.dart';
import 'follows_provider.dart';
import 'models/search_results.dart';
import 'search_design.dart';
import 'search_provider.dart';
import 'widgets/cofradeo_search_bar.dart';
import 'widgets/profile_search_tile.dart';
import 'widgets/search_empty_state.dart';
import 'widgets/search_recent_chip.dart';
import 'widgets/search_section_header.dart';
import 'widgets/trend_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _localFollowedTrends = <String>{};
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
  }

  void _applyRecentSearch(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onQueryChanged(query);
  }

  void _applyRouteQuery() {
    final q = GoRouterState.of(context).uri.queryParameters['q'];
    if (q == null || q.isEmpty) return;
    final decoded = Uri.decodeComponent(q);
    if (decoded == _query.trim()) return;
    _applyRecentSearch(decoded);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyRouteQuery();
    });
  }

  bool _isFollowingTrend(SearchTrend trend) {
    final user = ref.watch(currentUserProvider);
    final supabaseReady = ref.watch(supabaseReadyProvider);

    if (user != null && supabaseReady) {
      final followed = ref.watch(followedHashtagsProvider).asData?.value;
      return followed?.contains(trend.hashtag) ?? false;
    }

    return _localFollowedTrends.contains(trend.id);
  }

  Future<void> _toggleFollow(SearchTrend trend) async {
    final user = ref.read(currentUserProvider);
    final supabaseReady = ref.read(supabaseReadyProvider);

    if (user == null) {
      if (context.mounted) {
        await context.push('/login?redirect=${Uri.encodeComponent('/buscar')}');
      }
      return;
    }

    if (!await ensureEmailVerifiedForEngage(context, ref)) return;

    if (!supabaseReady) {
      setState(() {
        if (_localFollowedTrends.contains(trend.id)) {
          _localFollowedTrends.remove(trend.id);
        } else {
          _localFollowedTrends.add(trend.id);
        }
      });
      return;
    }

    final followed = ref.read(followedHashtagsProvider).asData?.value ?? {};
    final isFollowing = followed.contains(trend.hashtag);

    try {
      await ref
          .read(hashtagFollowControllerProvider)
          .toggle(hashtag: trend.hashtag, currentlyFollowing: isFollowing);
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push('/login?redirect=${Uri.encodeComponent('/buscar')}');
      }
    } on FollowsUnavailableException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el seguimiento.')),
        );
      }
    }
  }

  List<String> _recentQueries(bool supabaseReady) {
    final stored = ref.watch(recentSearchesProvider).asData?.value ?? const [];
    if (stored.isNotEmpty) return stored;
    if (!supabaseReady) return mockRecentSearches;
    return stored;
  }

  bool get _isSearching => _query.trim().isNotEmpty;

  Widget _buildTrendCard(SearchTrend trend) {
    return TrendCard(
      trend: trend,
      isFollowing: _isFollowingTrend(trend),
      onFollowToggle: () => _toggleFollow(trend),
      onHashtagTap: () => _applyRecentSearch(trend.hashtag),
    );
  }

  Widget _buildResultsHeader(String query, SearchResults results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resultados',
          style: SearchDesign.sectionTitle(),
        ),
        const SizedBox(height: 4),
        Text(
          results.summaryLabel.isEmpty
              ? 'Buscando «$query»…'
              : '${results.summaryLabel} para «$query»',
          style: SearchDesign.resultsSummary(),
        ),
      ],
    );
  }

  Widget _buildResultsList(SearchResults results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (results.profiles.isNotEmpty) ...[
          SearchSectionHeader(
            icon: Icons.person_outline_rounded,
            label: 'Perfiles',
            count: results.profiles.length,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < results.profiles.length; i++) ...[
            if (i > 0) const SizedBox(height: SearchDesign.cardGap),
            ProfileSearchTile(
              profile: results.profiles[i],
              onTap: () => context.push(
                '/perfil/usuario/${results.profiles[i].id}',
              ),
            ),
          ],
          const SizedBox(height: SearchDesign.sectionGap),
        ],
        if (results.events.isNotEmpty) ...[
          SearchSectionHeader(
            icon: Icons.event_outlined,
            label: 'Eventos',
            count: results.events.length,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < results.events.length; i++) ...[
            if (i > 0) const SizedBox(height: SearchDesign.cardGap),
            EventCard(
              event: results.events[i],
              showBookmark: false,
              onTap: () {
                final event = results.events[i];
                ref.read(calendarFocusRequestProvider.notifier).setFocus(
                      CalendarFocusRequest(
                        month: DateTime(event.date.year, event.date.month),
                        day: event.date.day,
                        event: event,
                      ),
                    );
                context.go('/calendario');
              },
            ),
          ],
          const SizedBox(height: SearchDesign.sectionGap),
        ],
        if (results.topics.isNotEmpty) ...[
          SearchSectionHeader(
            icon: Icons.forum_outlined,
            label: 'Temas',
            count: results.topics.length,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < results.topics.length; i++) ...[
            if (i > 0) const SizedBox(height: SearchDesign.cardGap),
            TopicCard(
              topic: results.topics[i],
              onTap: () => context.push(
                '/foros/${results.topics[i].forumId}/tema/${results.topics[i].id}',
              ),
            ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _query.trim();
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final searchAsync = _isSearching
        ? ref.watch(searchResultsProvider(trimmedQuery))
        : null;
    final trendsAsync = ref.watch(searchTrendsProvider);
    final recentQueries = _recentQueries(supabaseReady);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: forumsBeigeDecorationImage(context),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                SearchDesign.screenPadding,
                10,
                SearchDesign.screenPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'BUSCAR',
                            style: SearchDesign.screenTitle(),
                          ),
                        ),
                        const CalendarQuickAccessButton(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CofradeoSearchBar(
                      controller: _controller,
                      onChanged: _onQueryChanged,
                      onClear: () => _onQueryChanged(''),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSearching) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SearchDesign.screenPadding,
                  22,
                  SearchDesign.screenPadding,
                  8,
                ),
                sliver: SliverToBoxAdapter(
                  child: searchAsync?.maybeWhen(
                        data: (results) =>
                            _buildResultsHeader(trimmedQuery, results),
                        orElse: () => _buildResultsHeader(
                          trimmedQuery,
                          SearchResults.empty,
                        ),
                      ) ??
                      _buildResultsHeader(trimmedQuery, SearchResults.empty),
                ),
              ),
              if (searchAsync == null)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else
                searchAsync.when(
                  loading: () => SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SearchDesign.screenPadding,
                      vertical: 32,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.burgundy.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SearchDesign.screenPadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'No se pudieron cargar los resultados.',
                        style: SearchDesign.resultsSummary(),
                      ),
                    ),
                  ),
                  data: (results) {
                    if (results.isEmpty) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SearchDesign.screenPadding,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: SearchEmptyState(query: trimmedQuery),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        SearchDesign.screenPadding,
                        0,
                        SearchDesign.screenPadding,
                        28,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildResultsList(results),
                      ),
                    );
                  },
                ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SearchDesign.screenPadding,
                  12,
                  SearchDesign.screenPadding,
                  0,
                ),
                sliver: const SliverToBoxAdapter(
                  child: SponsoredPlacementSlot(
                    placement: AdPlacement.search,
                    compact: true,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SearchDesign.screenPadding,
                  14,
                  SearchDesign.screenPadding,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: SearchSectionHeader(
                    icon: Icons.trending_up_rounded,
                    label: 'Tendencias',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SearchDesign.screenPadding,
                ),
                sliver: trendsAsync.when(
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Cargando tendencias…',
                        style: SearchDesign.sectionMeta(),
                      ),
                    ),
                  ),
                  error: (_, __) => SliverToBoxAdapter(
                    child: Text(
                      supabaseReady
                          ? 'No se pudieron cargar las tendencias.'
                          : 'Sin conexión a Supabase.',
                      style: SearchDesign.sectionMeta(),
                    ),
                  ),
                  data: (trends) {
                    if (trends.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: SearchDesign.cardDecoration(),
                          child: Text(
                            'Aún no hay hashtags en el foro. '
                            'Escribe #Algo en un tema o respuesta.',
                            style: SearchDesign.resultsSummary(),
                          ),
                        ),
                      );
                    }

                    return SliverList.separated(
                      itemCount: trends.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: SearchDesign.cardGap),
                      itemBuilder: (context, index) =>
                          _buildTrendCard(trends[index]),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SearchDesign.screenPadding,
                  24,
                  SearchDesign.screenPadding,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: SearchSectionHeader(
                    icon: Icons.history_rounded,
                    label: 'Recientes',
                    count: recentQueries.isEmpty ? null : recentQueries.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  SearchDesign.screenPadding,
                  0,
                  SearchDesign.screenPadding,
                  28,
                ),
                sliver: SliverToBoxAdapter(
                  child: recentQueries.isEmpty
                      ? Text(
                          'Tus búsquedas recientes aparecerán aquí.',
                          style: SearchDesign.sectionMeta(),
                        )
                      : SearchRecentChipsWrap(
                          queries: recentQueries,
                          onTap: _applyRecentSearch,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
