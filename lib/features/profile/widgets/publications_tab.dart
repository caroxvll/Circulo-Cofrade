import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../../../shared/models/profile_activity.dart';
import '../../auth/auth_provider.dart';
import '../../forums/constants/topic_moderation_copy.dart';
import '../data/hidden_activity_store.dart';
import '../profile_design.dart';
import '../profile_provider.dart';
import 'profile_activity_card.dart';
import 'profile_activity_filters.dart';
import 'profile_screen_header.dart';

const _pageSize = 15;

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
  int? _visibleLimit;
  Set<String>? _hiddenIds;
  final _hiddenStore = HiddenActivityStore();

  ActivityFeedFilter get _activeFilter => _filter ?? ActivityFeedFilter.all;
  int get _activeVisibleLimit => _visibleLimit ?? _pageSize;
  Set<String> get _activeHiddenIds => _hiddenIds ?? const {};

  @override
  void initState() {
    super.initState();
    _filter = ActivityFeedFilter.all;
    _visibleLimit = _pageSize;
    _hiddenIds = {};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHiddenIds();
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    _filter ??= ActivityFeedFilter.all;
    _visibleLimit ??= _pageSize;
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
    setState(() => _hiddenIds = next);
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
    setState(() => _hiddenIds = {});
    await _hiddenStore.clear(widget.userId);
  }

  void _onFilterSelected(ActivityFeedFilter filter) {
    setState(() {
      _filter = filter;
      _visibleLimit = _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthenticated) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          ProfileDesign.screenPadding,
          ProfileDesign.sectionGap,
          ProfileDesign.screenPadding,
          28,
        ),
        children: [
          Text(
            'Próximamente',
            style: AppTypography.displaySmall(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final supabaseReady = ref.watch(supabaseReadyProvider);
    final activityAsync = ref.watch(userActivityProvider(widget.userId));
    final hiddenIds = _isOwnProfile ? _activeHiddenIds : const <String>{};

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userActivityProvider(widget.userId));
        await ref.read(userActivityProvider(widget.userId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          ProfileDesign.screenPadding,
          12,
          ProfileDesign.screenPadding,
          28,
        ),
        children: [
          if (!supabaseReady)
            Text(
              'Conecta Supabase para ver publicaciones reales.',
              style: AppTypography.bodyMedium(),
              textAlign: TextAlign.center,
            )
          else
            activityAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(
                'No se pudieron cargar las publicaciones.',
                style: AppTypography.bodyMedium(),
              ),
              data: (activities) => _ActivityFeed(
                activities: activities,
                filter: _activeFilter,
                hiddenIds: hiddenIds,
                visibleLimit: _activeVisibleLimit,
                isOwnProfile: _isOwnProfile,
                userId: widget.userId,
                onFilterSelected: _onFilterSelected,
                onHide: _hideActivity,
                onLoadMore: () {
                  setState(() => _visibleLimit = _activeVisibleLimit + _pageSize);
                },
                onRestoreHidden: _restoreHidden,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({
    required this.activities,
    required this.filter,
    required this.hiddenIds,
    required this.visibleLimit,
    required this.isOwnProfile,
    required this.userId,
    required this.onFilterSelected,
    required this.onHide,
    required this.onLoadMore,
    required this.onRestoreHidden,
  });

  final List<ProfileActivity> activities;
  final ActivityFeedFilter filter;
  final Set<String> hiddenIds;
  final int visibleLimit;
  final bool isOwnProfile;
  final String userId;
  final ValueChanged<ActivityFeedFilter> onFilterSelected;
  final Future<void> Function(ProfileActivity) onHide;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRestoreHidden;

  @override
  Widget build(BuildContext context) {
    final pendingTopics = activities
        .where((a) => a.isTopic && a.topicStatus == TopicStatus.pending)
        .length;

    final visible = filterActivities(activities, filter, hiddenIds);
    final page = visible.take(visibleLimit).toList();
    final hasMore = visible.length > visibleLimit;

    if (activities.isEmpty) {
      return ProfileEmptyState(
        icon: Icons.grid_view_outlined,
        title: 'Aún no hay publicaciones',
        subtitle: 'Cuando publiques en los foros aparecerán aquí '
            'con su estado.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingTopics > 0) ...[
          _PendingTopicsBanner(count: pendingTopics),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: ProfileDesign.activityPanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileActivitySectionHeader(
                count: visible.length,
                isOwnProfile: isOwnProfile,
              ),
              const SizedBox(height: 12),
              Text(
                'FILTRAR ACTIVIDAD',
                style: ProfileDesign.filterSectionLabel(),
              ),
              const SizedBox(height: 8),
              ProfileActivityFilters(
                filter: filter,
                onSelected: onFilterSelected,
              ),
              if (isOwnProfile && hiddenIds.isNotEmpty) ...[
                const SizedBox(height: 8),
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
                      'Mostrar ${hiddenIds.length} oculto${hiddenIds.length == 1 ? '' : 's'}',
                      style: ProfileDesign.meta().copyWith(
                        color: AppColors.burgundy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                filter == ActivityFeedFilter.all && hiddenIds.isNotEmpty
                    ? 'Todo oculto. Pulsa «Mostrar ocultos» para recuperar.'
                    : 'Nada en esta categoría.',
                style: AppTypography.bodyMedium(),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          for (final activity in page)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: isOwnProfile
                  ? _DismissibleActivityCard(
                      activity: activity,
                      onHide: () => onHide(activity),
                    )
                  : ProfileActivityCard(activity: activity),
            ),
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: onLoadMore,
                child: Text(
                  'Cargar más (${visible.length - visibleLimit} restantes)',
                  style: AppTypography.bodyMedium(color: AppColors.burgundy),
                ),
              ),
            ),
        ],
      ],
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
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: AppColors.burgundy.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(ProfileDesign.cardRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 18,
              color: AppColors.burgundy.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            Text(
              'Ocultar',
              style: AppTypography.labelSmall(
                color: AppColors.burgundy,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onHide(),
      child: ProfileActivityCard(activity: activity),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_outlined, color: AppColors.burgundy, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count tema${count == 1 ? '' : 's'} en revisión',
                  style: AppTypography.titleLarge().copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  TopicModerationCopy.profilePendingHint,
                  style: AppTypography.bodyMedium().copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
