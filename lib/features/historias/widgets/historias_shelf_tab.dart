import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../search/follows_provider.dart';
import '../cronicon_brand.dart';
import '../historias_provider.dart';
import '../models/historia.dart';
import 'cronicon_mark.dart';
import 'historia_compose_sheet.dart';
import 'historia_cover_card.dart';
import 'historia_follow_button.dart';

class HistoriasShelfTab extends ConsumerStatefulWidget {
  const HistoriasShelfTab({super.key});

  @override
  ConsumerState<HistoriasShelfTab> createState() => _HistoriasShelfTabState();
}

class _HistoriasShelfTabState extends ConsumerState<HistoriasShelfTab> {
  HistoriaKind? _filter;
  var _onlyFollowing = false;
  final _scroll = ScrollController();

  HistoriasShelfQuery get _query => HistoriasShelfQuery(
        kind: _filter,
        onlyFollowing: _onlyFollowing,
      );

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 720) {
      ref.read(publishedHistoriasFeedProvider(_query).notifier).loadMore();
    }
  }

  Future<void> _write({Historia? existing}) async {
    final created = await showHistoriaPublishSheet(
      context,
      existing: existing,
    );
    if (created) {
      ref.invalidate(publishedHistoriasFeedProvider);
      ref.invalidate(publishedHistoriasProvider);
      ref.invalidate(myHistoriasProvider);
    }
  }

  Future<void> _openWorkshop() async {
    final mine = await ref.read(myHistoriasProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _WorkshopSheet(
        items: mine,
        onNew: () {
          Navigator.pop(context);
          _write();
        },
        onEdit: (historia) {
          Navigator.pop(context);
          _write(existing: historia);
        },
        onRead: (historia) {
          Navigator.pop(context);
          context.push('/historias/${historia.id}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(publishedHistoriasFeedProvider(_query));
    final canPublish = ref.watch(canPublishHistoriasProvider);
    final followed =
        ref.watch(followedProfilesProvider).asData?.value ?? const <String>{};

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar las historias.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (page) {
        final items = page.items;
        Historia? featured;
        if (!_onlyFollowing && _filter == null && items.isNotEmpty) {
          featured = items
                  .where((item) => followed.contains(item.authorId))
                  .firstOrNull ??
              items.first;
        }
        final grid = featured == null
            ? items
            : items.where((item) => item.id != featured!.id).toList();
        final followedAuthors = <String, Historia>{};
        for (final item in items) {
          if (followed.contains(item.authorId)) {
            followedAuthors.putIfAbsent(item.authorId, () => item);
          }
        }

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publishedHistoriasFeedProvider(_query));
                if (canPublish) ref.invalidate(myHistoriasProvider);
                await ref.read(publishedHistoriasFeedProvider(_query).future);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ShelfIntro(
                          canPublish: canPublish,
                          onWorkshop: _openWorkshop,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _KindFilterBar(
                          selected: _filter,
                          onlyFollowing: _onlyFollowing,
                          onSelected: (kind) => setState(() {
                            _filter = kind;
                            _onlyFollowing = false;
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                          }),
                          onFollowing: () => setState(() {
                            _onlyFollowing = true;
                            _filter = null;
                            if (_scroll.hasClients) _scroll.jumpTo(0);
                          }),
                        ),
                      ),
                      if (!_onlyFollowing && followedAuthors.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _FollowedAuthorsRow(
                            authors: followedAuthors.values.toList(),
                          ),
                        ),
                      if (featured != null)
                        SliverToBoxAdapter(
                          child: _FeaturedWork(historia: featured),
                        ),
                      if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyShelf(
                            kind: _filter,
                            following: _onlyFollowing,
                          ),
                        )
                      else if (grid.isNotEmpty) ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                HistoriaCoverCard.gridDelegateFor(
                              constraints.maxWidth,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => HistoriaCoverCard(
                                historia: grid[index],
                              ),
                              childCount: grid.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                            child: page.isLoadingMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : page.hasMore
                                    ? TextButton(
                                        onPressed: () => ref
                                            .read(
                                              publishedHistoriasFeedProvider(
                                                _query,
                                              ).notifier,
                                            )
                                            .loadMore(),
                                        child: const Text('Ver más obras'),
                                      )
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ] else
                        const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    ],
                  );
                },
              ),
            ),
            if (canPublish)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _write(),
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Publicar'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeaturedWork extends StatelessWidget {
  const _FeaturedWork({required this.historia});

  final Historia historia;

  @override
  Widget build(BuildContext context) {
    final excerpt = historia.excerpt.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: InkWell(
        onTap: () => context.push('/historias/${historia.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HistoriaCoverCard(
              historia: historia,
              width: 148,
              showMeta: false,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      historia.kind.label.toUpperCase(),
                      style: AppTypography.labelSmall(color: AppColors.goldDark)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (excerpt.isNotEmpty)
                      Text(
                        excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bookCaption(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 15, height: 1.45),
                      ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => context.push(
                        '/historias/autor/${historia.authorId}',
                      ),
                      child: Text(
                        historia.authorDisplayName,
                        style: AppTypography.labelSmall(color: AppColors.goldDark)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    HistoriaFollowButton(
                      authorId: historia.authorId,
                      compact: true,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Abrir el libro →',
                      style: AppTypography.labelSmall(color: AppColors.burgundy)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindFilterBar extends StatelessWidget {
  const _KindFilterBar({
    required this.selected,
    required this.onlyFollowing,
    required this.onSelected,
    required this.onFollowing,
  });

  final HistoriaKind? selected;
  final bool onlyFollowing;
  final ValueChanged<HistoriaKind?> onSelected;
  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) {
    final chipStyle = AppTypography.labelSmall(
      color: AppColors.burgundy,
    ).copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: selected == null && !onlyFollowing,
            onSelected: (_) => onSelected(null),
            selectedColor: AppColors.goldPale,
            labelStyle: chipStyle,
          ),
          ChoiceChip(
            label: const Text('Siguiendo'),
            selected: onlyFollowing,
            onSelected: (_) => onFollowing(),
            selectedColor: AppColors.goldPale,
            labelStyle: chipStyle,
          ),
          for (final kind in HistoriaKind.values)
            ChoiceChip(
              label: Text(kind.label),
              selected: selected == kind,
              onSelected: (_) => onSelected(kind),
              selectedColor: AppColors.goldPale,
              labelStyle: chipStyle,
            ),
        ],
      ),
    );
  }
}

class _FollowedAuthorsRow extends StatelessWidget {
  const _FollowedAuthorsRow({required this.authors});

  final List<Historia> authors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus cronistas', style: AppTypography.sectionTitle()),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: authors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final author = authors[index];
                return InkWell(
                  onTap: () =>
                      context.push('/historias/autor/${author.authorId}'),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        CofradeoAvatar(
                          imageUrl: author.authorAvatarUrl,
                          size: 44,
                          backgroundColor: AppColors.backgroundElevated,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          author.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall(
                            color: AppColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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

class _ShelfIntro extends StatelessWidget {
  const _ShelfIntro({
    required this.canPublish,
    required this.onWorkshop,
  });

  final bool canPublish;
  final VoidCallback onWorkshop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: CroniconMasthead(
        trailing: canPublish
            ? TextButton(
                onPressed: onWorkshop,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.burgundy,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Tu taller'),
              )
            : null,
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({this.kind, this.following = false});

  final HistoriaKind? kind;
  final bool following;

  @override
  Widget build(BuildContext context) {
    final filtered = kind != null;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: AppColors.goldDark.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            following
                ? 'Nada de quien sigues'
                : filtered
                    ? 'Aún no hay ${kind!.label.toLowerCase()}s'
                    : '${CroniconBrand.name} está en blanco',
            style: AppTypography.titleLarge(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            following
                ? 'Entra en su ficha y pulsa Seguir. Sus obras saldrán aquí primero.'
                : filtered
                    ? 'Cuando alguien publique este formato, aparecerá aquí.'
                    : 'Cuando un cronista publique, su obra saldrá aquí, con el sello de ${CroniconBrand.imprint}.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WorkshopSheet extends StatelessWidget {
  const _WorkshopSheet({
    required this.items,
    required this.onNew,
    required this.onEdit,
    required this.onRead,
  });

  final List<Historia> items;
  final VoidCallback onNew;
  final ValueChanged<Historia> onEdit;
  final ValueChanged<Historia> onRead;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tu taller', style: AppTypography.titleLarge()),
            const SizedBox(height: 4),
            Text(
              'En ${CroniconBrand.name}. Edita un borrador o una obra ya publicada; el resto ve el sello.',
              style: AppTypography.bodyMedium(),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                'Todavía no tienes nada guardado.',
                style: AppTypography.bodyMedium(),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final historia = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(historia.title),
                      subtitle: Text(
                        '${historia.kind.label} · ${historia.isDraft ? 'Borrador' : historia.isPublished ? 'Publicada' : 'Oculta'}',
                      ),
                      onTap: () => onEdit(historia),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!historia.isDraft)
                            IconButton(
                              tooltip: 'Leer',
                              onPressed: () => onRead(historia),
                              icon: const Icon(Icons.menu_book_outlined),
                            ),
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => onEdit(historia),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onNew,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
              ),
              child: const Text('Escribir'),
            ),
          ],
        ),
      ),
    );
  }
}
