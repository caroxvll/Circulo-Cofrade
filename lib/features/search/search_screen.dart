import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_typography.dart';
import '../../core/widgets/screen_title_row.dart';
import '../auth/auth_provider.dart';
import '../auth/email_verification_gate.dart';
import '../calendar/calendar_provider.dart';
import '../calendar/models/calendar_focus_request.dart';
import '../calendar/widgets/event_card.dart';
import '../forums/widgets/topic_card.dart';
import 'data/follows_repository.dart';
import 'data/mock_search.dart';
import 'follows_provider.dart';
import 'search_provider.dart';
import 'widgets/cofradeo_search_bar.dart';
import 'widgets/profile_search_tile.dart';
import 'widgets/recent_search_tile.dart';
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
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/buscar')}',
        );
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
      await ref.read(hashtagFollowControllerProvider).toggle(
            hashtag: trend.hashtag,
            currentlyFollowing: isFollowing,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push(
          '/login?redirect=${Uri.encodeComponent('/buscar')}',
        );
      }
    } on FollowsUnavailableException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el seguimiento.'),
          ),
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

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = _query.trim();
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final searchAsync = _isSearching
        ? ref.watch(searchResultsProvider(trimmedQuery))
        : null;
    final trendsAsync = ref.watch(searchTrendsProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ScreenTitleRow(title: 'Buscar'),
                  const SizedBox(height: 16),
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Resultados',
                  style: AppTypography.displaySmall(),
                ),
              ),
            ),
            if (searchAsync == null)
              const SliverToBoxAdapter(child: SizedBox.shrink())
            else
              searchAsync.when(
                loading: () => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Buscando…',
                      style: AppTypography.bodyMedium(),
                    ),
                  ),
                ),
                error: (_, __) => SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'No se pudieron cargar los resultados.',
                      style: AppTypography.bodyMedium(),
                    ),
                  ),
                ),
                data: (results) {
                  if (results.isEmpty) {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'No hay resultados para «$trimmedQuery».',
                          style: AppTypography.bodyMedium(),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (results.profiles.isNotEmpty) ...[
                          Text(
                            'Perfiles',
                            style: AppTypography.titleLarge(),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < results.profiles.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            ProfileSearchTile(
                              profile: results.profiles[i],
                              onTap: () => context.push(
                                '/perfil/usuario/${results.profiles[i].id}',
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                        if (results.events.isNotEmpty) ...[
                          Text(
                            'Eventos',
                            style: AppTypography.titleLarge(),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < results.events.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            EventCard(
                              event: results.events[i],
                              onTap: () {
                                final event = results.events[i];
                                ref
                                    .read(calendarFocusRequestProvider.notifier)
                                    .setFocus(
                                  CalendarFocusRequest(
                                    month: DateTime(
                                      event.date.year,
                                      event.date.month,
                                    ),
                                    day: event.date.day,
                                    event: event,
                                  ),
                                );
                                context.go('/calendario');
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                        if (results.topics.isNotEmpty) ...[
                          Text(
                            'Temas',
                            style: AppTypography.titleLarge(),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < results.topics.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            TopicCard(
                              topic: results.topics[i],
                              onTap: () => context.push(
                                '/foros/${results.topics[i].forumId}/tema/${results.topics[i].id}',
                              ),
                            ),
                          ],
                        ],
                      ]),
                    ),
                  );
                },
              ),
          ] else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text('Tendencias', style: AppTypography.displaySmall()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: trendsAsync.when(
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Cargando tendencias…',
                      style: AppTypography.bodyMedium(),
                    ),
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: Text(
                    supabaseReady
                        ? 'No se pudieron cargar las tendencias.'
                        : 'Sin conexión a Supabase.',
                    style: AppTypography.bodyMedium(),
                  ),
                ),
                data: (trends) {
                  if (trends.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Text(
                        'Aún no hay hashtags en el foro. '
                        'Escribe #Algo en un tema o respuesta.',
                        style: AppTypography.bodyMedium(),
                      ),
                    );
                  }

                  return SliverList.separated(
                    itemCount: trends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildTrendCard(trends[index]),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Búsquedas Recientes',
                  style: AppTypography.displaySmall(),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recentQueries = _recentQueries(supabaseReady);
                    if (recentQueries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Tus búsquedas recientes aparecerán aquí.',
                          style: AppTypography.bodyMedium(),
                        ),
                      );
                    }

                    final query = recentQueries[index];
                    return RecentSearchTile(
                      query: query,
                      onTap: () => _applyRecentSearch(query),
                    );
                  },
                  childCount: _recentQueries(supabaseReady).isEmpty
                      ? 1
                      : _recentQueries(supabaseReady).length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
