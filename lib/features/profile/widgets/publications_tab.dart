import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/models/forum.dart';
import '../../../shared/models/profile_activity.dart';
import '../../auth/auth_provider.dart';
import '../../forums/constants/topic_moderation_copy.dart';
import '../../notifications/notifications_provider.dart';
import '../data/hidden_activity_store.dart';
import '../profile_provider.dart';
import 'profile_stats_card.dart';

const _pageSize = 15;

class PublicationsTab extends ConsumerStatefulWidget {
  const PublicationsTab({
    super.key,
    required this.userId,
    required this.publicationCount,
    required this.followerCount,
    required this.isAuthenticated,
  });

  final String userId;
  final int publicationCount;
  final int followerCount;
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
      _syncActivityIfNeeded();
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

  void _syncActivityIfNeeded() {
    if (!widget.isAuthenticated) return;

    final notifications = ref.read(notificationsProvider).asData?.value;
    if (notifications == null) return;

    final hasModerationUpdate = notifications.any(
      (n) =>
          n.kind == AppNotificationKind.topicPublished ||
          n.kind == AppNotificationKind.topicRejected,
    );
    if (hasModerationUpdate) {
      ref.invalidate(userActivityProvider(widget.userId));
    }
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          ProfileStatsCard(
            publicationCount: widget.publicationCount,
            followerCount: widget.followerCount,
          ),
          const SizedBox(height: 32),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          ProfileStatsCard(
            publicationCount: widget.publicationCount,
            followerCount: widget.followerCount,
          ),
          const SizedBox(height: 24),
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
      return Column(
        children: [
          Icon(
            Icons.grid_view_outlined,
            size: 40,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no hay publicaciones',
            style: AppTypography.displaySmall(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando publiques en los foros aparecerán aquí con su estado.',
            style: AppTypography.bodyMedium(),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingTopics > 0) ...[
          _PendingTopicsBanner(count: pendingTopics),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu actividad',
                    style: AppTypography.titleLarge().copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOwnProfile
                        ? 'Desliza para ocultar · no borra del foro'
                        : 'Temas y respuestas en los foros.',
                    style: AppTypography.bodyMedium(),
                  ),
                ],
              ),
            ),
            if (isOwnProfile && hiddenIds.isNotEmpty)
              TextButton(
                onPressed: onRestoreHidden,
                child: Text(
                  'Mostrar ${hiddenIds.length} oculto${hiddenIds.length == 1 ? '' : 's'}',
                  style: AppTypography.labelSmall(color: AppColors.burgundy)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _FilterChips(
          filter: filter,
          activities: activities,
          hiddenIds: hiddenIds,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: 14),
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
                  : _ActivityCard(activity: activity),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.activities,
    required this.hiddenIds,
    required this.onSelected,
  });

  final ActivityFeedFilter filter;
  final List<ProfileActivity> activities;
  final Set<String> hiddenIds;
  final ValueChanged<ActivityFeedFilter> onSelected;

  int _count(ActivityFeedFilter f) {
    return filterActivities(activities, f, hiddenIds).length;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ActivityFeedFilter.values.map((f) {
        final selected = filter == f;
        final count = _count(f);
        return FilterChip(
          label: Text('${activityFilterLabel(f)} ($count)'),
          selected: selected,
          onSelected: (selected) {
            if (selected) onSelected(f);
          },
          selectedColor: AppColors.chipSelected,
          checkmarkColor: AppColors.burgundy,
          labelStyle: AppTypography.labelSmall(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
          side: BorderSide(
            color: selected ? AppColors.goldLight : AppColors.border,
          ),
        );
      }).toList(),
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
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.visibility_off_outlined, size: 20),
            SizedBox(width: 6),
            Text('Ocultar'),
          ],
        ),
      ),
      onDismissed: (_) => onHide(),
      child: _ActivityCard(activity: activity),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldPale.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_outlined, color: AppColors.burgundy, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count tema${count == 1 ? '' : 's'} en revisión',
                  style: AppTypography.titleLarge().copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  TopicModerationCopy.profilePendingHint,
                  style: AppTypography.bodyMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final ProfileActivity activity;

  Color _borderColor() {
    if (!activity.isTopic) return AppColors.border;
    return switch (activity.topicStatus) {
      TopicStatus.pending => AppColors.gold,
      TopicStatus.rejected => AppColors.textMuted.withValues(alpha: 0.5),
      _ => AppColors.border,
    };
  }

  Color _badgeBackground() {
    if (!activity.isTopic) return AppColors.backgroundElevated;
    return switch (activity.topicStatus) {
      TopicStatus.pending => AppColors.burgundy,
      TopicStatus.rejected => AppColors.textMuted.withValues(alpha: 0.35),
      TopicStatus.published => AppColors.burgundy.withValues(alpha: 0.12),
      null => AppColors.backgroundElevated,
    };
  }

  Color _badgeTextColor() {
    if (!activity.isTopic) return AppColors.burgundy;
    return switch (activity.topicStatus) {
      TopicStatus.pending => AppColors.textOnDark,
      TopicStatus.rejected => AppColors.textPrimary,
      TopicStatus.published => AppColors.burgundy,
      null => AppColors.burgundy,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push(
          '/foros/${activity.forumId}/tema/${activity.topicId}',
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _borderColor(),
              width: activity.isTopic &&
                      activity.topicStatus == TopicStatus.pending
                  ? 1.5
                  : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeBackground(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activity.isTopic
                          ? 'Tema · ${activity.typeLabel}'
                          : activity.typeLabel,
                      style: AppTypography.labelSmall(color: _badgeTextColor()),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    activity.timeAgo,
                    style: AppTypography.labelSmall(color: AppColors.accentRed),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                activity.title,
                style: AppTypography.titleLarge().copyWith(fontSize: 15),
              ),
              if (activity.preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  activity.preview,
                  style: AppTypography.bodyMedium(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
