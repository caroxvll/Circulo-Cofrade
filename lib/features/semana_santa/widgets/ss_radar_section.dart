import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/cofradeo_asset_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../auth/auth_provider.dart';
import '../../cuaresma/widgets/cuaresma_hub_design.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/utils/hermandad_local_assets.dart';
import '../../forums/widgets/forum_post_image_viewer.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import '../utils/ss_informar_helpers.dart';
import 'ss_live_design.dart';

/// Timeline en directo del hub (scroll continuo, estilo feed).
class SemanaSantaRadarSection extends ConsumerStatefulWidget {
  const SemanaSantaRadarSection({
    super.key,
    required this.forumId,
    required this.topicId,
    this.fillHeight = false,
    this.onRefresh,
  });

  final String forumId;
  final String topicId;
  final bool fillHeight;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<SemanaSantaRadarSection> createState() =>
      _SemanaSantaRadarSectionState();
}

class _SemanaSantaRadarSectionState
    extends ConsumerState<SemanaSantaRadarSection> {
  void _openInformar(BuildContext context) {
    context.push(
      '/foros/${widget.forumId}/tema/${widget.topicId}/informar',
    );
  }

  @override
  Widget build(BuildContext context) {
    final kindFilter = ref.watch(ssLiveFeedFilterProvider);
    final feedAsync = ref.watch(ssLiveFeedProvider);
    final canInform = ref.watch(ssCanInformProvider).asData?.value ?? false;
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    final rawDayLabel = gate?.activeDay?.label;
    final dayLabel = rawDayLabel?.trim();
    final hasActiveDay = dayLabel != null && dayLabel.isNotEmpty;
    final sectionSubtitle = hasActiveDay
        ? 'Jornada: $dayLabel · últimas 12 h'
        : 'Sin jornada activa · el directo está en pausa';

    if (!hasActiveDay) {
      final dormant = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 32,
                color: AppColors.burgundy.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),
              Text(
                'No hay jornada abierta',
                textAlign: TextAlign.center,
                style: TopicDetailTypography.body().copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cuando Temporada active Dolores, Pasión o un día santo, aquí saldrán los avisos de las hermandades.',
                textAlign: TextAlign.center,
                style: TopicDetailTypography.meta(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 12.5, height: 1.35),
              ),
            ],
          ),
        ),
      );
      if (!widget.fillHeight) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(sectionSubtitle, style: TopicDetailTypography.sectionSubtitle()),
            const SizedBox(height: 12),
            dormant,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(sectionSubtitle, style: TopicDetailTypography.sectionSubtitle()),
          const SizedBox(height: 8),
          Expanded(child: dormant),
        ],
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: CuaresmaHubLiveBadge(compact: true),
        ),
        const SizedBox(height: 4),
        Text(
          sectionSubtitle,
          style: TopicDetailTypography.sectionSubtitle(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _KindChip(
                label: 'Todos',
                selected: kindFilter == null,
                color: AppColors.burgundy,
                icon: Icons.grid_view_rounded,
                onTap: () =>
                    ref.read(ssLiveFeedFilterProvider.notifier).setFilter(null),
              ),
              const SizedBox(width: 6),
              for (final kind in SsLiveUpdateKind.values) ...[
                _KindChip(
                  label: kind.label,
                  selected: kindFilter == kind,
                  color: ssKindColor(kind),
                  icon: ssKindIcon(kind),
                  onTap: () {
                    final notifier = ref.read(ssLiveFeedFilterProvider.notifier);
                    notifier.setFilter(kindFilter == kind ? null : kind);
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );

    Widget emptyFeed() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 28,
              color: AppColors.burgundy.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 8),
            Text(
              kindFilter == null
                  ? (canInform
                      ? 'Todavía no hay avisos. Sé el primero.'
                      : 'Todavía no hay avisos en directo.')
                  : 'Ningún aviso con este filtro.',
              textAlign: TextAlign.center,
              style: TopicDetailTypography.meta(
                color: AppColors.textSecondary,
              ),
            ),
            if (kindFilter == null && !canInform) ...[
              const SizedBox(height: 6),
              Text(
                'Los publican hermandades y reporteros de confianza.\nTú puedes reaccionar y comentar.',
                textAlign: TextAlign.center,
                style: TopicDetailTypography.meta(
                  color: AppColors.textMuted,
                ).copyWith(fontSize: 12, height: 1.35),
              ),
            ],
            if (canInform)
              TextButton(
                onPressed: () => _openInformar(context),
                child: const Text('+ Informar'),
              ),
          ],
        ),
      );
    }

    if (!widget.fillHeight) {
      return feedAsync.when(
        skipLoadingOnReload: true,
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 8),
            const HubSectionListSkeleton(itemCount: 3),
          ],
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 8),
            Text(
              'No se pudieron cargar los avisos.',
              style: TopicDetailTypography.meta(color: AppColors.textSecondary),
            ),
          ],
        ),
        data: (updates) {
          if (updates.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                emptyFeed(),
              ],
            );
          }
          final preview = updates.take(3).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 4),
              for (final u in preview) SsLiveHubCompactTile(update: u),
            ],
          );
        },
      );
    }

    final refresh = widget.onRefresh;

    Widget pinnedHeaderSliver() {
      return SliverPersistentHeader(
        pinned: true,
        delegate: _SsFeedStickyHeaderDelegate(child: header),
      );
    }

    return RefreshIndicator(
      color: AppColors.burgundy,
      onRefresh: refresh ?? () async {},
      child: feedAsync.when(
        skipLoadingOnReload: true,
        loading: () => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            pinnedHeaderSliver(),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: HubSectionListSkeleton(itemCount: 4),
              ),
            ),
          ],
        ),
        error: (_, _) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            pinnedHeaderSliver(),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No se pudieron cargar los avisos.',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        data: (updates) {
          if (updates.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                pinnedHeaderSliver(),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: emptyFeed()),
                ),
              ],
            );
          }

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              pinnedHeaderSliver(),
              SliverList.separated(
                itemCount: updates.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.55),
                ),
                itemBuilder: (context, index) =>
                    SsLiveHubCompactTile(update: updates[index]),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }
}

class _SsFeedStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SsFeedStickyHeaderDelegate({required this.child});

  final Widget child;

  /// Badge + subtítulo + chips (+ márgenes).
  static const double _height = 98;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      elevation: overlapsContent || shrinkOffset > 0.5 ? 1.5 : 0,
      shadowColor: AppColors.burgundyDark.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SsFeedStickyHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

class SsLiveHubCompactTile extends ConsumerWidget {
  const SsLiveHubCompactTile({
    super.key,
    required this.update,
  });

  final SsLiveUpdate update;

  SsDayHermandadOption? _matchHermandad(List<SsDayHermandadOption> options) {
    final needle = update.hermandadLabel?.trim().toLowerCase() ?? '';
    if (needle.isEmpty) return null;
    for (final o in options) {
      final name = o.name.toLowerCase();
      if (name == needle || name.contains(needle) || needle.contains(name)) {
        return o;
      }
    }
    return null;
  }

  Future<void> _setReaction(WidgetRef ref, String? reaction) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final previous = ref
        .read(ssLiveEngagementProvider)
        .asData
        ?.value
        .userReactionFor(update.id);
    await ref.read(ssLiveEngagementRepositoryProvider).setReaction(
          userId: user.id,
          updateId: update.id,
          reaction: reaction,
        );
    ref.read(ssLiveEngagementProvider.notifier).applyLocalReaction(
          updateId: update.id,
          userId: user.id,
          previous: previous,
          next: reaction,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ssKindColor(update.kind);
    final hermandad = update.hermandadLabel?.trim();
    final place = update.placeLabel?.trim();
    final title = (hermandad != null && hermandad.isNotEmpty)
        ? hermandad
        : update.authorHandle;
    final dayOptions =
        ref.watch(ssDayHermandadesProvider).asData?.value ?? const [];
    final matched = _matchHermandad(dayOptions);
    final remote = matched?.iconImageUrl?.trim();
    final localAvatar = matched == null
        ? null
        : HermandadLocalAssets.avatar(
            processionDay: matched.processionDay,
            hermandadName: matched.name,
          );
    final handle = update.authorHandle.startsWith('@')
        ? update.authorHandle
        : '@${update.authorHandle}';
    final official = update.isOfficial;
    final author = official ? handle : 'vía $handle';
    final badgeColor = official ? AppColors.burgundy : AppColors.gold;
    final badgeLabel = official ? 'Oficial' : 'Reportero';
    final badgeIcon =
        official ? Icons.verified_rounded : Icons.campaign_outlined;
    final engagement = ref.watch(ssLiveEngagementProvider).asData?.value;
    final counts = engagement?.countsFor(update.id) ?? const <String, int>{};
    final userReaction = engagement?.userReactionFor(update.id);
    final replyCount = engagement?.replyCountFor(update.id) ?? 0;
    final canEngage = ref.watch(currentUserProvider) != null;

    return Material(
      color: official
          ? AppColors.burgundy.withValues(alpha: 0.035)
          : Colors.transparent,
      child: InkWell(
        onTap: () => showSsLiveUpdateDetailSheet(context, update: update),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.08),
                  border: Border.all(
                    color: official
                        ? AppColors.burgundy.withValues(alpha: 0.5)
                        : AppColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: remote != null && remote.isNotEmpty
                    ? CofradeoNetworkImage(
                        url: remote,
                        fit: BoxFit.contain,
                        width: 42,
                        height: 42,
                        cacheSize: 84,
                        placeholder: const CofradeoSkeletonBone(
                          width: 42,
                          height: 42,
                          borderRadius: 21,
                        ),
                        errorWidget: Icon(
                          Icons.church_outlined,
                          size: 18,
                          color: color,
                        ),
                      )
                    : localAvatar != null
                        ? CofradeoAssetImage(
                            assetPath: localAvatar,
                            fit: BoxFit.contain,
                          )
                        : Icon(
                            Icons.church_outlined,
                            size: 18,
                            color: color,
                          ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TopicDetailTypography.body().copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(badgeIcon, size: 13, color: badgeColor),
                        const SizedBox(width: 3),
                        Text(
                          badgeLabel,
                          style: TopicDetailTypography.meta(
                            color: badgeColor,
                            fontWeight: FontWeight.w800,
                          ).copyWith(fontSize: 11),
                        ),
                        Text(
                          ' · ${formatTimeAgo(update.createdAt)}',
                          style: TopicDetailTypography.meta(
                            color: AppColors.textMuted,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: author,
                            style: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ).copyWith(fontSize: 11.5),
                          ),
                          TextSpan(
                            text: ' · ',
                            style: TopicDetailTypography.meta(
                              color: AppColors.textMuted,
                            ).copyWith(fontSize: 11.5),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              ssKindIcon(update.kind),
                              size: 12,
                              color: color,
                            ),
                          ),
                          TextSpan(
                            text: ' ${update.kind.label}',
                            style: TopicDetailTypography.meta(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ).copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      update.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TopicDetailTypography.body().copyWith(
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (update.hasImage) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => showForumPostImageViewer(
                          context,
                          imageUrl: update.imageUrl!,
                          shareText: update.message,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: CofradeoNetworkImage(
                              url: update.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              cacheSize: 720,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (place != null && place.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TopicDetailTypography.meta(
                                color: AppColors.textMuted,
                              ).copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SsLiveReactionsBar(
                            reactionCounts: counts,
                            userReaction: userReaction,
                            enabled: canEngage,
                            onReactionChanged:
                                canEngage ? (r) => _setReaction(ref, r) : null,
                          ),
                        ),
                        InkWell(
                          onTap: () => showSsLiveUpdateDetailSheet(
                            context,
                            update: update,
                            openReplies: true,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 15,
                                  color: replyCount > 0
                                      ? AppColors.burgundy
                                      : AppColors.textMuted,
                                ),
                                if (replyCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '$replyCount',
                                    style: TopicDetailTypography.meta(
                                      color: AppColors.burgundy,
                                      fontWeight: FontWeight.w700,
                                    ).copyWith(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSsLiveUpdateDetailSheet(
  BuildContext context, {
  required SsLiveUpdate update,
  bool openReplies = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _SsLiveUpdateDetailSheet(
      update: update,
      openReplies: openReplies,
    ),
  );
}

class _SsLiveUpdateDetailSheet extends ConsumerStatefulWidget {
  const _SsLiveUpdateDetailSheet({
    required this.update,
    this.openReplies = false,
  });

  final SsLiveUpdate update;
  final bool openReplies;

  @override
  ConsumerState<_SsLiveUpdateDetailSheet> createState() =>
      _SsLiveUpdateDetailSheetState();
}

class _SsLiveUpdateDetailSheetState
    extends ConsumerState<_SsLiveUpdateDetailSheet> {
  late var _repliesOpen = widget.openReplies;
  var _postingReply = false;
  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.openReplies) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replyFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _setReaction(String? reaction) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final previous = ref
        .read(ssLiveEngagementProvider)
        .asData
        ?.value
        .userReactionFor(widget.update.id);
    await ref.read(ssLiveEngagementRepositoryProvider).setReaction(
          userId: user.id,
          updateId: widget.update.id,
          reaction: reaction,
        );
    ref.read(ssLiveEngagementProvider.notifier).applyLocalReaction(
          updateId: widget.update.id,
          userId: user.id,
          previous: previous,
          next: reaction,
        );
  }

  Future<void> _submitReply() async {
    final user = ref.read(currentUserProvider);
    final text = _replyController.text.trim();
    if (user == null || text.isEmpty || _postingReply) return;

    setState(() => _postingReply = true);
    try {
      await ref.read(ssLiveEngagementRepositoryProvider).postReply(
            userId: user.id,
            updateId: widget.update.id,
            message: text,
          );
      _replyController.clear();
      ref.invalidate(ssLiveRepliesProvider(widget.update.id));
      ref.read(ssLiveEngagementProvider.notifier).applyLocalReplyDelta(
            widget.update.id,
            1,
          );
      if (!_repliesOpen) setState(() => _repliesOpen = true);
    } finally {
      if (mounted) setState(() => _postingReply = false);
    }
  }

  void _toggleReplies() {
    final next = !_repliesOpen;
    setState(() => _repliesOpen = next);
    if (next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replyFocus.requestFocus();
      });
    } else {
      _replyFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final color = ssKindColor(update.kind);
    final hermandad = update.hermandadLabel?.trim();
    final place = update.placeLabel?.trim();
    final handle = update.authorHandle.startsWith('@')
        ? update.authorHandle
        : '@${update.authorHandle}';
    final author = update.isOfficial ? handle : 'vía $handle';
    final title = (hermandad != null && hermandad.isNotEmpty)
        ? hermandad
        : handle;
    final engagement = ref.watch(ssLiveEngagementProvider).asData?.value;
    final counts = engagement?.countsFor(update.id) ?? const <String, int>{};
    final userReaction = engagement?.userReactionFor(update.id);
    final replyCount = engagement?.replyCountFor(update.id) ?? 0;
    final canEngage = ref.watch(currentUserProvider) != null;
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * (_repliesOpen ? 0.72 : 0.52);
    final keyboard = media.viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: sheetHeight,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TopicDetailTypography.body().copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  author,
                  style: TopicDetailTypography.meta(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '·',
                  style: TopicDetailTypography.meta(color: AppColors.textMuted),
                ),
                Text(
                  formatTimeAgo(update.createdAt),
                  style: TopicDetailTypography.meta(color: AppColors.textMuted),
                ),
                if (update.isOfficial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: AppColors.burgundy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Oficial',
                          style: TopicDetailTypography.meta(
                            color: AppColors.burgundy,
                            fontWeight: FontWeight.w800,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 13,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reportero',
                          style: TopicDetailTypography.meta(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(ssKindIcon(update.kind), size: 13, color: color),
                      const SizedBox(width: 4),
                      Text(
                        update.kind.label,
                        style: TopicDetailTypography.meta(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (place != null && place.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      place,
                      style: TopicDetailTypography.meta(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Text(
                    update.message,
                    style: TopicDetailTypography.body().copyWith(
                      fontSize: 15.5,
                      height: 1.45,
                    ),
                  ),
                  if (update.hasImage) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => showForumPostImageViewer(
                        context,
                        imageUrl: update.imageUrl!,
                        shareText: update.message,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CofradeoNetworkImage(
                          url: update.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220,
                          cacheSize: 960,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SsLiveReactionsBar(
                          reactionCounts: counts,
                          userReaction: userReaction,
                          enabled: canEngage,
                          onReactionChanged: canEngage ? _setReaction : null,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _toggleReplies,
                        icon: Icon(
                          _repliesOpen
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                          size: 16,
                        ),
                        label: Text(
                          replyCount > 0
                              ? 'Respuestas ($replyCount)'
                              : 'Responder',
                        ),
                      ),
                    ],
                  ),
                  if (_repliesOpen) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    SsLiveRepliesPanel(
                      updateId: update.id,
                      controller: _replyController,
                      focusNode: _replyFocus,
                      posting: _postingReply,
                      canPost: canEngage,
                      onSubmit: _submitReply,
                      showComposer: false,
                    ),
                  ],
                ],
              ),
            ),
            if (_repliesOpen)
              SsLiveReplyComposer(
                controller: _replyController,
                focusNode: _replyFocus,
                posting: _postingReply,
                canPost: canEngage,
                onSubmit: _submitReply,
              ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : AppColors.backgroundElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TopicDetailTypography.meta(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
