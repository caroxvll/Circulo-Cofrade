import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';
import '../../../shared/models/forum.dart';
import '../../../shared/models/profile_activity.dart';
import '../../auth/auth_provider.dart';
import '../../forums/constants/topic_moderation_copy.dart';
import '../data/hidden_activity_store.dart';
import '../profile_design.dart';
import '../profile_provider.dart';
import 'profile_activity_card.dart';
import 'profile_topics_empty_state.dart';

const _pageSize = 2;

class PublicationsTab extends ConsumerStatefulWidget {
  const PublicationsTab({
    super.key,
    required this.userId,
    required this.isAuthenticated,
  });

  final String userId;
  final bool isAuthenticated;

  @override
  ConsumerState<PublicationsTab> createState() => _PublicationsTabState();
}

class _PublicationsTabState extends ConsumerState<PublicationsTab> {
  ActivityFeedFilter? _filter;
  int _pageIndex = 0;
  Set<String>? _hiddenIds;
  final _hiddenStore = HiddenActivityStore();

  ActivityFeedFilter get _activeFilter =>
      _filter ?? ActivityFeedFilter.topics;
  Set<String> get _activeHiddenIds => _hiddenIds ?? const {};

  @override
  void initState() {
    super.initState();
    _filter = ActivityFeedFilter.topics;
    _pageIndex = 0;
    _hiddenIds = {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHiddenIds();
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _filter ??= ActivityFeedFilter.topics;
    _hiddenIds ??= {};
  }

  Future<void> _loadHiddenIds() async {
    if (!_isOwnProfile) return;
    final ids = await _hiddenStore.load(widget.userId);
    if (mounted) setState(() => _hiddenIds = ids);
  }

  bool get _isOwnProfile {
    final currentId = ref.read(currentUserProvider)?.id;
    return widget.isAuthenticated && currentId == widget.userId;
  }

  Future<void> _hideActivity(ProfileActivity activity) async {
    final next = {..._activeHiddenIds, activity.id};
    setState(() {
      _hiddenIds = next;
      _pageIndex = 0;
    });
    await _hiddenStore.save(widget.userId, next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oculto de tu perfil. Sigue visible en el foro.'),
        ),
      );
    }
  }

  Future<void> _restoreHidden() async {
    setState(() {
      _hiddenIds = {};
      _pageIndex = 0;
    });
    await _hiddenStore.clear(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthenticated) {
      return const Center(child: Text('Próximamente'));
    }

    final supabaseReady = ref.watch(supabaseReadyProvider);
    final activityAsync = ref.watch(userActivityProvider(widget.userId));
    final hiddenIds = _isOwnProfile ? _activeHiddenIds : const <String>{};

    if (!supabaseReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ProfileDesign.screenPadding),
          child: Text(
            'Conecta Supabase para ver publicaciones reales.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return activityAsync.when(
      skipLoadingOnReload: true,
      loading: () => const PeopleListSkeleton(itemCount: 5),
      error: (_, _) => Center(
        child: Text(
          'No se pudieron cargar las publicaciones.',
          style: AppTypography.bodyMedium(),
        ),
      ),
      data: (activities) => _ActivityFeed(
        activities: activities,
        filter: _activeFilter,
        hiddenIds: hiddenIds,
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        isOwnProfile: _isOwnProfile,
        onHide: _hideActivity,
        onPageChanged: (page) => setState(() => _pageIndex = page),
        onRestoreHidden: _restoreHidden,
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({
    required this.activities,
    required this.filter,
    required this.hiddenIds,
    required this.pageIndex,
    required this.pageSize,
    required this.isOwnProfile,
    required this.onHide,
    required this.onPageChanged,
    required this.onRestoreHidden,
  });

  final List<ProfileActivity> activities;
  final ActivityFeedFilter filter;
  final Set<String> hiddenIds;
  final int pageIndex;
  final int pageSize;
  final bool isOwnProfile;
  final Future<void> Function(ProfileActivity) onHide;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onRestoreHidden;

  @override
  Widget build(BuildContext context) {
    final pendingTopics = activities
        .where((a) => a.isTopic && a.topicStatus == TopicStatus.pending)
        .length;

    final visible = filterActivities(activities, filter, hiddenIds);
    final pageCount =
        visible.isEmpty ? 0 : ((visible.length + pageSize - 1) ~/ pageSize);
    final safePage = pageCount == 0 ? 0 : pageIndex.clamp(0, pageCount - 1);
    final start = safePage * pageSize;
    final pageItems = visible.skip(start).take(pageSize).toList();

    // Altura exacta del viewport: 2 temas + pager, sin scroll vacío.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        if (!maxH.isFinite || maxH <= 0) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: maxH,
          width: constraints.maxWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ProfileDesign.screenPadding,
              4,
              ProfileDesign.screenPadding,
              4,
            ),
            child: activities.isEmpty
                ? ProfileTopicsEmptyState(isOwnProfile: isOwnProfile)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (pendingTopics > 0) ...[
                        _PendingTopicsBanner(count: pendingTopics),
                        const SizedBox(height: 6),
                      ],
                      if (isOwnProfile && hiddenIds.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onRestoreHidden,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.burgundy,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Mostrar ${hiddenIds.length} oculto'
                              '${hiddenIds.length == 1 ? '' : 's'}',
                              style: ProfileDesign.meta().copyWith(
                                color: AppColors.burgundy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (visible.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              filter == ActivityFeedFilter.all &&
                                      hiddenIds.isNotEmpty
                                  ? 'Todo oculto. Pulsa «Mostrar ocultos» '
                                      'para recuperar.'
                                  : 'Nada en esta categoría.',
                              style: AppTypography.bodyMedium(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: Column(
                            children: [
                              for (var i = 0; i < pageItems.length; i++) ...[
                                if (i > 0) const SizedBox(height: 6),
                                Expanded(
                                  child: isOwnProfile
                                      ? _DismissibleActivityCard(
                                          activity: pageItems[i],
                                          onHide: () =>
                                              onHide(pageItems[i]),
                                        )
                                      : ProfileActivityCard(
                                          activity: pageItems[i],
                                          dense: true,
                                          fillHeight: true,
                                        ),
                                ),
                              ],
                              if (pageItems.length == 1)
                                const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        ),
                        if (pageCount > 1)
                          _TopicsPager(
                            pageIndex: safePage,
                            pageCount: pageCount,
                            onPageChanged: onPageChanged,
                          ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _TopicsPager extends StatelessWidget {
  const _TopicsPager({
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

class _DismissibleActivityCard extends StatelessWidget {
  const _DismissibleActivityCard({
    required this.activity,
    required this.onHide,
  });

  final ProfileActivity activity;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('hide-${activity.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onHide();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.burgundy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
        ),
        child: const Icon(
          Icons.visibility_off_outlined,
          color: AppColors.burgundy,
        ),
      ),
      child: ProfileActivityCard(
        activity: activity,
        dense: true,
        fillHeight: true,
      ),
    );
  }
}

class _PendingTopicsBanner extends StatelessWidget {
  const _PendingTopicsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        count == 1
            ? TopicModerationCopy.profilePendingHint
            : 'Tienes $count temas en revisión por la Junta. '
                'Aparecen aquí hasta que se publiquen.',
        style: AppTypography.bodyMedium(
          color: AppColors.goldDark,
        ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
