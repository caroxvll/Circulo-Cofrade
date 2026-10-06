import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../../shared/models/followed_topic.dart';
import '../../../shared/models/forum.dart';
import '../../forums/forums_provider.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../forums/utils/hermandad_local_assets.dart';
import '../../forums/widgets/hermandad_follow_sections_sheet.dart';
import '../../search/follows_provider.dart';
import '../profile_design.dart';
import 'profile_people_mode.dart';
import 'profile_screen_header.dart';

const _pageSize = 5;
/// Una fila de 2 cards a altura completa (sin scroll).
const _discoverPageSize = 2;

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

enum _FollowKind { hermandad, hilo, hashtag }

enum _FollowFilter { hermandad, hilo, hashtag }

class _FollowEntry {
  const _FollowEntry.hermandad(this.topic)
      : kind = _FollowKind.hermandad,
        hashtag = null;
  const _FollowEntry.hilo(this.topic)
      : kind = _FollowKind.hilo,
        hashtag = null;
  const _FollowEntry.hashtag(this.hashtag)
      : kind = _FollowKind.hashtag,
        topic = null;

  final _FollowKind kind;
  final FollowedTopic? topic;
  final String? hashtag;

  String get searchText {
    switch (kind) {
      case _FollowKind.hermandad:
        final parsed = parseHermandadTopicTitle(topic!.title);
        return '${parsed.hermandadName} ${parsed.processionDay ?? ''}';
      case _FollowKind.hilo:
        return '${topic!.title} ${topic!.preview}';
      case _FollowKind.hashtag:
        return hashtag!;
    }
  }
}

/// Pestaña Siguiendo: hermandades, hilos y hashtags (paginado + búsqueda).
class FollowingTab extends ConsumerStatefulWidget {
  const FollowingTab({super.key});

  @override
  ConsumerState<FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends ConsumerState<FollowingTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _pageIndex = 0;
  /// Paginación propia del directorio (no mezclar con hilos/hashtags).
  int _discoverPageIndex = 0;
  /// Al abrir Siguiendo: primero el espacio de hermandades.
  _FollowFilter _filter = _FollowFilter.hermandad;
  /// Con hermandades ya seguidas: entrar al directorio para seguir más.
  bool _exploreMoreHermandades = false;

  @override
  void initState() {
    super.initState();
    HermandadLocalAssets.ensureLoaded();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_FollowEntry> _buildEntries({
    required List<FollowedTopic> topics,
    required Set<String> hashtags,
  }) {
    final hermandades = topics.where((t) => t.isHermandadBoard).toList();
    final hilos = topics.where((t) => !t.isHermandadBoard).toList();
    final tags = hashtags.toList()..sort();

    return [
      for (final t in hermandades) _FollowEntry.hermandad(t),
      for (final t in hilos) _FollowEntry.hilo(t),
      for (final tag in tags) _FollowEntry.hashtag(tag),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hashtagsAsync = ref.watch(followedHashtagsProvider);
    final topicsAsync = ref.watch(followedTopicsDetailsProvider);

    return topicsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const HermandadCardsSkeleton(),
      error: (_, _) =>
          const Center(child: Text('Error al cargar seguimientos')),
      data: (topics) {
        final hashtags = hashtagsAsync.asData?.value ?? {};
        final all = _buildEntries(topics: topics, hashtags: hashtags);
        final hermandadCount =
            all.where((e) => e.kind == _FollowKind.hermandad).length;

        // Sin seguimientos: en hermandades mostramos el directorio; en el resto, vacío.
        if (all.isEmpty && _filter != _FollowFilter.hermandad) {
          return const Padding(
            padding: EdgeInsets.all(ProfileDesign.screenPadding),
            child: Center(
              child: ProfileEmptyState(
                icon: Icons.bookmark_outline_rounded,
                title: 'Aún no sigues foros',
                subtitle:
                    'Elige tu hermandad en el chip de arriba, o sigue '
                    'hilos y hashtags desde Buscar.',
              ),
            ),
          );
        }

        final byFilter = all.where((e) {
          switch (_filter) {
            case _FollowFilter.hermandad:
              return e.kind == _FollowKind.hermandad;
            case _FollowFilter.hilo:
              return e.kind == _FollowKind.hilo;
            case _FollowFilter.hashtag:
              return e.kind == _FollowKind.hashtag;
          }
        }).toList();

        final filtered = (_filter == _FollowFilter.hermandad)
            ? byFilter
            : byFilter.where((e) {
                final q = _query.trim().toLowerCase();
                if (q.isEmpty) return true;
                return e.searchText.toLowerCase().contains(q);
              }).toList();

        final hermandadGrid = _filter == _FollowFilter.hermandad;
        final pageSize = hermandadGrid ? _discoverPageSize : _pageSize;
        final pageCount = filtered.isEmpty
            ? 0
            : ((filtered.length + pageSize - 1) ~/ pageSize);
        final safePage =
            pageCount == 0 ? 0 : _pageIndex.clamp(0, pageCount - 1);
        if (safePage != _pageIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _pageIndex = safePage);
          });
        }
        final start = safePage * pageSize;
        final pageItems = filtered.skip(start).take(pageSize).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            if (!maxH.isFinite || maxH <= 0) {
              return const SizedBox.shrink();
            }

            return SizedBox(
              height: maxH,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ProfileDesign.screenPadding,
                  6,
                  ProfileDesign.screenPadding,
                  4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FollowingHeader(
                      filter: _filter,
                      hermandadCount: hermandadCount,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in _FollowFilter.values) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(switch (f) {
                                  _FollowFilter.hermandad => hermandadCount == 0
                                      ? 'Hermandades'
                                      : hermandadCount == 1
                                          ? 'Tu hermandad'
                                          : 'Tus hermandades',
                                  _FollowFilter.hilo => 'Hilos',
                                  _FollowFilter.hashtag => 'Hashtags',
                                }),
                                selected: _filter == f,
                                onSelected: (_) => setState(() {
                                  _filter = f;
                                  _pageIndex = 0;
                                  _discoverPageIndex = 0;
                                  _exploreMoreHermandades = false;
                                }),
                                selectedColor: AppColors.chipSelected,
                                labelStyle: AppTypography.labelSmall(
                                  color: _filter == f
                                      ? AppColors.chipSelectedText
                                      : AppColors.textSecondary,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_filter == _FollowFilter.hermandad &&
                        (hermandadCount == 0 || _exploreMoreHermandades))
                      Expanded(
                        child: _HermandadDiscoverPane(
                          query: _query,
                          searchController: _searchCtrl,
                          followedTopicIds: {
                            for (final e in all)
                              if (e.kind == _FollowKind.hermandad)
                                e.topic!.topicId,
                          },
                          showBackToMine: hermandadCount > 0,
                          onBackToMine: () => setState(() {
                            _exploreMoreHermandades = false;
                            _discoverPageIndex = 0;
                          }),
                          onQueryChanged: (value) => setState(() {
                            _query = value;
                            _discoverPageIndex = 0;
                          }),
                          pageIndex: _discoverPageIndex,
                          onPageChanged: (page) =>
                              setState(() => _discoverPageIndex = page),
                        ),
                      )
                    else ...[
                      if (_filter == _FollowFilter.hermandad &&
                          hermandadCount > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _exploreMoreHermandades = true;
                              _discoverPageIndex = 0;
                              _query = '';
                              _searchCtrl.clear();
                            }),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Seguir otra'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.burgundy,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        )
                      else ...[
                        ProfilePeopleSearchField(
                          controller: _searchCtrl,
                          hint: 'Buscar hilos o hashtags…',
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                              _pageIndex = 0;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              _query.trim().isEmpty
                                  ? 'Nada en este filtro.'
                                  : 'Ningún resultado para «${_query.trim()}».',
                              style: AppTypography.bodyMedium(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (_filter == _FollowFilter.hermandad)
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gap = 8.0;
                              final n = pageItems.length;
                              if (n == 1) {
                                // Misma proporción que una card del grid 2×1.
                                final cardW = (constraints.maxWidth - gap) / 2;
                                final cardH = constraints.maxHeight;
                                return Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: cardW,
                                    height: cardH,
                                    child: _HermandadFollowTile(
                                      topic: pageItems.first.topic!,
                                    ),
                                  ),
                                );
                              }
                              final cardW =
                                  (constraints.maxWidth - gap) / 2;
                              final ratio = cardW /
                                  constraints.maxHeight.clamp(1.0, 10000.0);
                              return GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: gap,
                                  crossAxisSpacing: gap,
                                  childAspectRatio: ratio,
                                ),
                                itemCount: n,
                                itemBuilder: (context, index) {
                                  return _HermandadFollowTile(
                                    topic: pageItems[index].topic!,
                                  );
                                },
                              );
                            },
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            physics: const ClampingScrollPhysics(),
                            itemCount: pageItems.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _FollowEntryTile(
                                entry: pageItems[index],
                              );
                            },
                          ),
                        ),
                      if (pageCount > 1)
                        _FollowingPager(
                          pageIndex: safePage,
                          pageCount: pageCount,
                          onPageChanged: (page) =>
                              setState(() => _pageIndex = page),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FollowingHeader extends StatelessWidget {
  const _FollowingHeader({
    required this.filter,
    required this.hermandadCount,
  });

  final _FollowFilter filter;
  final int hermandadCount;

  @override
  Widget build(BuildContext context) {
    final (icon, title, count) = switch (filter) {
      _FollowFilter.hermandad => (
          Icons.church_outlined,
          hermandadCount == 0
              ? 'Elige tu hermandad'
              : hermandadCount == 1
                  ? 'Tu hermandad'
                  : 'Tus hermandades',
          hermandadCount == 0 ? null : hermandadCount,
        ),
      _FollowFilter.hilo => (Icons.forum_outlined, 'Hilos que sigues', null),
      _FollowFilter.hashtag => (Icons.tag_rounded, 'Hashtags que sigues', null),
    };

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.goldDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: ProfileDesign.sectionTitle().copyWith(fontSize: 15),
          ),
        ),
        if (count != null && count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              '$count',
              style: ProfileDesign.meta().copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.burgundy,
              ),
            ),
          ),
      ],
    );
  }
}

class _FollowingPager extends StatelessWidget {
  const _FollowingPager({
    required this.pageIndex,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int pageIndex;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final canPrev = pageIndex > 0;
    final canNext = pageIndex < pageCount - 1;

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Anterior',
            onPressed: canPrev ? () => onPageChanged(pageIndex - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            color: AppColors.burgundy,
            disabledColor: AppColors.textMuted.withValues(alpha: 0.35),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text(
            '${pageIndex + 1} / $pageCount',
            style: AppTypography.labelSmall(
              color: AppColors.textSecondary,
            ).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          IconButton(
            tooltip: 'Siguiente',
            onPressed: canNext ? () => onPageChanged(pageIndex + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            color: AppColors.burgundy,
            disabledColor: AppColors.textMuted.withValues(alpha: 0.35),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _FollowEntryTile extends ConsumerWidget {
  const _FollowEntryTile({required this.entry});

  final _FollowEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (entry.kind) {
      _FollowKind.hermandad => _HermandadFollowTile(topic: entry.topic!),
      _FollowKind.hilo => _TopicFollowTile(topic: entry.topic!),
      _FollowKind.hashtag => _HashtagFollowTile(hashtag: entry.hashtag!),
    };
  }
}

/// Card premium de hermandad ya seguida (mismo lenguaje visual que el directorio).
class _HermandadFollowTile extends ConsumerWidget {
  const _HermandadFollowTile({required this.topic});

  final FollowedTopic topic;

  Future<void> _openNotifySheet(BuildContext context, WidgetRef ref) async {
    final outcome = await showHermandadFollowSectionsSheet(
      context,
      initialCategories: topic.notifyOfficialCategories,
      following: true,
    );
    if (!context.mounted || outcome == null) return;

    if (outcome.unfollow) {
      await ref.read(topicFollowControllerProvider).toggle(
            topicId: topic.topicId,
            currentlyFollowing: true,
          );
      return;
    }

    await ref.read(topicFollowControllerProvider).updateNotifyCategories(
          topicId: topic.topicId,
          notifyOfficialCategories: outcome.categories,
        );
  }

  void _openBoard(BuildContext context, {String? seccion}) {
    final base = '/foros/${topic.forumId}/tema/${topic.topicId}';
    final path = seccion == null ? base : '$base?seccion=$seccion';
    context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = parseHermandadTopicTitle(topic.title);
    final name = parsed.hermandadName;
    final day = parsed.processionDay;
    final remote = topic.iconImageUrl?.trim();
    final hasRemote = remote != null && remote.isNotEmpty;
    final localLogo = HermandadLocalAssets.avatar(
      processionDay: day,
      hermandadName: name,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.18),
      child: InkWell(
        onTap: () => _openBoard(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                AppAssets.hermandadCardBackground,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFF5F0E8),
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final showLinks = h >= 210;
                  final showDay = h >= 175;
                  final logoSize = (h * 0.28).clamp(40.0, 72.0);
                  final titleSize = h < 190 ? 12.5 : 14.0;
                  final btnH = h < 190 ? 24.0 : 26.0;

                  Widget logoWidget() {
                    if (hasRemote) {
                      return CofradeoNetworkImage(
                        url: remote,
                        fit: BoxFit.contain,
                        width: logoSize,
                        height: logoSize,
                        cacheSize: logoSize,
                        errorWidget: Icon(
                          Icons.church_outlined,
                          size: logoSize * 0.72,
                          color: AppColors.burgundy.withValues(alpha: 0.55),
                        ),
                      );
                    }
                    if (localLogo != null) {
                      return Image.asset(
                        localLogo,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      );
                    }
                    return Icon(
                      Icons.church_outlined,
                      size: logoSize * 0.72,
                      color: AppColors.burgundy.withValues(alpha: 0.55),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      h < 190 ? 6 : 8,
                      8,
                      h < 190 ? 6 : 8,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.bookmark_rounded,
                            size: 16,
                            color: AppColors.burgundy.withValues(alpha: 0.85),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: logoSize,
                              height: logoSize,
                              child: logoWidget(),
                            ),
                          ),
                        ),
                        Text(
                          name.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.hermandadName().copyWith(
                            fontSize: titleSize,
                          ),
                        ),
                        if (showDay && day != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            day,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.rankTitle(
                              color: AppColors.textSecondary,
                            ).copyWith(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (showLinks) ...[
                          const SizedBox(height: 4),
                          const _CardFleurDivider(),
                          const SizedBox(height: 3),
                          _CardLinkRow(
                            left: 'Noticias',
                            right: 'Cultos',
                            onLeft: () =>
                                _openBoard(context, seccion: 'noticias'),
                            onRight: () =>
                                _openBoard(context, seccion: 'cultos'),
                          ),
                          _CardLinkRow(
                            left: 'Actos',
                            right: 'Patrimonio',
                            onLeft: () =>
                                _openBoard(context, seccion: 'actos'),
                            onRight: () =>
                                _openBoard(context, seccion: 'patrimonio'),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: btnH,
                                child: Material(
                                  color: AppColors.burgundy,
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    onTap: () => _openBoard(context),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Center(
                                      child: Text(
                                        'Entrar',
                                        style: AppTypography.buttonLabel(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: AppColors.surface.withValues(alpha: 0.92),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _openNotifySheet(context, ref),
                                child: SizedBox(
                                  width: btnH,
                                  height: btnH,
                                  child: Icon(
                                    Icons.tune_outlined,
                                    size: 15,
                                    color: AppColors.burgundy,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicFollowTile extends ConsumerWidget {
  const _TopicFollowTile({required this.topic});

  final FollowedTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '/foros/${topic.forumId}/tema/${topic.topicId}',
        ),
        borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
        child: Ink(
          decoration: ProfileDesign.cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const _ForumIconBadge(icon: Icons.forum_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hilo',
                      style: AppTypography.labelSmall(
                        color: AppColors.goldDark,
                      ).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      topic.title,
                      style: AppTypography.titleLarge().copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (topic.preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        topic.preview,
                        style: ProfileDesign.meta().copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _UnfollowChip(
                onTap: () => ref.read(topicFollowControllerProvider).toggle(
                      topicId: topic.topicId,
                      currentlyFollowing: true,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HashtagFollowTile extends ConsumerWidget {
  const _HashtagFollowTile({required this.hashtag});

  final String hashtag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ProfileDesign.cardDecoration(),
      child: Row(
        children: [
          const _ForumIconBadge(icon: Icons.tag_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hashtag',
                  style: AppTypography.labelSmall(
                    color: AppColors.goldDark,
                  ).copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hashtag,
                  style: AppTypography.titleLarge().copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _UnfollowChip(
            onTap: () => ref.read(hashtagFollowControllerProvider).toggle(
                  hashtag: hashtag,
                  currentlyFollowing: true,
                ),
          ),
        ],
      ),
    );
  }
}

class _ForumIconBadge extends StatelessWidget {
  const _ForumIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: 18, color: AppColors.goldDark),
    );
  }
}

class _UnfollowChip extends StatelessWidget {
  const _UnfollowChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.85),
            ),
          ),
          child: Text(
            'Dejar',
            style: AppTypography.labelSmall(
              color: AppColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

/// Directorio premium cuando aún no sigues ninguna hermandad.
class _HermandadDiscoverPane extends ConsumerWidget {
  const _HermandadDiscoverPane({
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.pageIndex,
    required this.onPageChanged,
    this.followedTopicIds = const {},
    this.showBackToMine = false,
    this.onBackToMine,
  });

  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final Set<String> followedTopicIds;
  final bool showBackToMine;
  final VoidCallback? onBackToMine;

  List<ForumTopic> _ordered(List<ForumTopic> topics) {
    return [...topics]..sort((a, b) {
        final aDay = parseHermandadTopicTitle(a.title).processionDay ?? '';
        final bDay = parseHermandadTopicTitle(b.title).processionDay ?? '';
        final aIndex = _hermandadesDayOrder.indexOf(aDay);
        final bIndex = _hermandadesDayOrder.indexOf(bDay);
        final safeA =
            aIndex == -1 ? _hermandadesDayOrder.length : aIndex;
        final safeB =
            bIndex == -1 ? _hermandadesDayOrder.length : bIndex;
        if (safeA != safeB) return safeA.compareTo(safeB);
        return a.title.compareTo(b.title);
      });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(forumTopicsProvider('hermandades'));

    return boardsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const HermandadCardsSkeleton(showChrome: false),
      error: (_, _) => Center(
        child: Text(
          'No se pudo cargar el directorio de hermandades.',
          style: AppTypography.bodyMedium(),
          textAlign: TextAlign.center,
        ),
      ),
      data: (raw) {
        // Solo las que aún no sigues (para “Seguir otra”).
        final ordered = _ordered([
          for (final t in raw)
            if (!followedTopicIds.contains(t.id)) t,
        ]);

        var list = ordered;
        final q = query.trim().toLowerCase();
        if (q.isNotEmpty) {
          list = [
            for (final t in list)
              if (t.title.toLowerCase().contains(q)) t,
          ];
        }

        final pageCount = list.isEmpty
            ? 0
            : ((list.length + _discoverPageSize - 1) ~/ _discoverPageSize);
        final safePage =
            pageCount == 0 ? 0 : pageIndex.clamp(0, pageCount - 1);
        final pageItems = list
            .skip(safePage * _discoverPageSize)
            .take(_discoverPageSize)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBackToMine && onBackToMine != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: onBackToMine,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: AppColors.burgundy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          followedTopicIds.length == 1
                              ? 'Volver a tu hermandad'
                              : 'Volver a tus hermandades',
                          style: AppTypography.labelSmall(
                            color: AppColors.burgundy,
                          ).copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            ProfilePeopleSearchField(
              controller: searchController,
              hint: 'Buscar hermandad…',
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 6),
            if (list.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    q.isEmpty
                        ? 'No hay más hermandades para seguir.'
                        : 'Ninguna hermandad para «${query.trim()}».',
                    style: AppTypography.bodyMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = 8.0;
                    final cardW = (constraints.maxWidth - gap) / 2;
                    final cardH = constraints.maxHeight;
                    final ratio = cardW / cardH.clamp(1.0, 10000.0);
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        childAspectRatio: ratio,
                      ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        return _HermandadDiscoverTile(
                          topic: pageItems[index],
                        );
                      },
                    );
                  },
                ),
              ),
              if (pageCount > 1)
                _FollowingPager(
                  pageIndex: safePage,
                  pageCount: pageCount,
                  onPageChanged: onPageChanged,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _HermandadDiscoverTile extends ConsumerWidget {
  const _HermandadDiscoverTile({required this.topic});

  final ForumTopic topic;

  Future<void> _follow(BuildContext context, WidgetRef ref) async {
    final outcome = await showHermandadFollowSectionsSheet(
      context,
      following: false,
    );
    if (!context.mounted || outcome == null || outcome.unfollow) return;

    try {
      await ref.read(topicFollowControllerProvider).toggle(
            topicId: topic.id,
            currentlyFollowing: false,
            notifyOfficialCategories: outcome.categories,
          );
    } on FollowRequiresAuthException {
      if (context.mounted) {
        await context.push('/login?redirect=${Uri.encodeComponent('/perfil')}');
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo seguir la hermandad.')),
      );
    }
  }

  void _openBoard(BuildContext context, {String? seccion}) {
    final base = '/foros/${topic.forumId}/tema/${topic.id}';
    final path = seccion == null ? base : '$base?seccion=$seccion';
    context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = parseHermandadTopicTitle(topic.title);
    final name = parsed.hermandadName;
    final day = parsed.processionDay;
    final remote = topic.iconImageUrl?.trim();
    final hasRemote = remote != null && remote.isNotEmpty;
    final localLogo = HermandadLocalAssets.avatar(
      processionDay: day,
      hermandadName: name,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.18),
      child: InkWell(
        onTap: () => _openBoard(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                AppAssets.hermandadCardBackground,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFF5F0E8),
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final showLinks = h >= 210;
                  final showDay = h >= 175;
                  final logoSize = (h * 0.26).clamp(36.0, 68.0);
                  final titleSize = h < 190 ? 12.5 : 13.5;
                  final btnH = h < 190 ? 24.0 : 26.0;

                  Widget logoWidget() {
                    if (hasRemote) {
                      return CofradeoNetworkImage(
                        url: remote,
                        fit: BoxFit.contain,
                        width: logoSize,
                        height: logoSize,
                        cacheSize: logoSize,
                        errorWidget: Icon(
                          Icons.church_outlined,
                          size: logoSize * 0.72,
                          color: AppColors.burgundy.withValues(alpha: 0.55),
                        ),
                      );
                    }
                    if (localLogo != null) {
                      return Image.asset(
                        localLogo,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      );
                    }
                    return Icon(
                      Icons.church_outlined,
                      size: logoSize * 0.72,
                      color: AppColors.burgundy.withValues(alpha: 0.55),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      h < 190 ? 6 : 8,
                      8,
                      h < 190 ? 6 : 8,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            size: 14,
                            color: AppColors.textMuted.withValues(alpha: 0.65),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: logoSize,
                              height: logoSize,
                              child: logoWidget(),
                            ),
                          ),
                        ),
                        Text(
                          name.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.hermandadName().copyWith(
                            fontSize: titleSize,
                          ),
                        ),
                        if (showDay && day != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            day,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.rankTitle(
                              color: AppColors.textSecondary,
                            ).copyWith(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (showLinks) ...[
                          const SizedBox(height: 4),
                          const _CardFleurDivider(),
                          const SizedBox(height: 3),
                          _CardLinkRow(
                            left: 'Noticias',
                            right: 'Cultos',
                            onLeft: () =>
                                _openBoard(context, seccion: 'noticias'),
                            onRight: () =>
                                _openBoard(context, seccion: 'cultos'),
                          ),
                          _CardLinkRow(
                            left: 'Actos',
                            right: 'Patrimonio',
                            onLeft: () =>
                                _openBoard(context, seccion: 'actos'),
                            onRight: () =>
                                _openBoard(context, seccion: 'patrimonio'),
                          ),
                        ],
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: btnH,
                          child: Material(
                            color: AppColors.burgundy,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: () => _follow(context, ref),
                              borderRadius: BorderRadius.circular(999),
                              child: Center(
                                child: Text(
                                  'Seguir  +',
                                  style: AppTypography.buttonLabel().copyWith(
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFleurDivider extends StatelessWidget {
  const _CardFleurDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 0.7,
            color: AppColors.border.withValues(alpha: 0.85),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.diamond_outlined,
            size: 8,
            color: AppColors.goldDark.withValues(alpha: 0.85),
          ),
        ),
        Expanded(
          child: Container(
            height: 0.7,
            color: AppColors.border.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _CardLinkRow extends StatelessWidget {
  const _CardLinkRow({
    required this.left,
    required this.right,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.labelSmall(
      color: AppColors.textSecondary,
    ).copyWith(fontSize: 11, fontWeight: FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onLeft,
          child: Text(left, style: style),
        ),
        Text('  ·  ', style: style),
        GestureDetector(
          onTap: onRight,
          child: Text(right, style: style),
        ),
      ],
    );
  }
}
