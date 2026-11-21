import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../hermandad_season_acts_provider.dart';
import '../utils/hermandad_season_acts.dart';
import '../utils/hermandad_season_profile.dart';
import 'hermandad_season_profile_sheet.dart';
import 'reply_compose_sheet.dart';

/// Línea de temporada: igualá → ensayos → muda → desarmá.
class HermandadSeasonActsCard extends ConsumerWidget {
  const HermandadSeasonActsCard({
    super.key,
    required this.topicId,
    required this.topicTitle,
    required this.forumId,
    this.canPublish = false,
  });

  final String topicId;
  final String topicTitle;
  final String forumId;
  final bool canPublish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      hermandadSeasonActsProvider((topicId: topicId, title: topicTitle)),
    );

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (snapshot) => _SeasonActsBody(
        snapshot: snapshot,
        canPublish: canPublish,
        onPublish: (kind) => _publishKind(context, ref, kind),
        onConfigure: canPublish
            ? () async {
                final saved = await showHermandadSeasonProfileSheet(
                  context,
                  topicId: topicId,
                  hermandadName: snapshot.hermandadName,
                );
                if (saved) {
                  ref.invalidate(
                    hermandadSeasonActsProvider(
                      (topicId: topicId, title: topicTitle),
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }

  Future<void> _publishKind(
    BuildContext context,
    WidgetRef ref,
    HermandadSeasonActKind kind, {
    String? publishId,
  }) async {
    final id = publishId ??
        switch (kind) {
          HermandadSeasonActKind.iguala => 'iguala',
          HermandadSeasonActKind.ensayos => 'ensayo',
          HermandadSeasonActKind.muda => 'muda',
          HermandadSeasonActKind.desarma => 'desarma',
        };
    await showReplyComposeSheet(
      context,
      ref,
      forumId: forumId,
      topicId: topicId,
      initialOfficialCategory: id,
    );
  }
}

class _SeasonActsBody extends StatelessWidget {
  const _SeasonActsBody({
    required this.snapshot,
    required this.canPublish,
    required this.onPublish,
    this.onConfigure,
  });

  final HermandadSeasonActsSnapshot snapshot;
  final bool canPublish;
  final ValueChanged<HermandadSeasonActKind> onPublish;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final missing = snapshot.milestones.where((m) => !m.isFilled).toList();
    final subtitle = snapshot.isComplete
        ? 'Temporada ${snapshot.year} completa'
        : snapshot.isEmpty
            ? canPublish
                ? 'Aún no hay actos publicados este año'
                : 'Cuando publiquen actos, aparecerán aquí'
            : '${snapshot.filledCount} de ${snapshot.totalCount} actos · ${snapshot.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEMPORADA ${snapshot.year}',
                      style: AppTypography.labelSmall(
                        color: AppColors.goldDark,
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Igualá, ensayos, ${snapshot.profile.mudaMode.shortLabel.toLowerCase()} y desarmá',
                      style:
                          AppTypography.hermandadName().copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (onConfigure != null)
                IconButton(
                  tooltip: 'Cómo es vuestra temporada',
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune_rounded),
                  color: AppColors.burgundy,
                ),
              _CoverageRing(
                filled: snapshot.filledCount,
                total: snapshot.totalCount,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MilestonesTrack(
            milestones: snapshot.milestones,
            profile: snapshot.profile,
            canPublish: canPublish,
            onPublish: onPublish,
          ),
          if (canPublish && missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in missing)
                  ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.burgundy,
                    ),
                    label: Text(
                      'Publicar ${item.kind.shortLabelFor(snapshot.profile).toLowerCase()}',
                    ),
                    onPressed: () => onPublish(item.kind),
                    backgroundColor: AppColors.backgroundElevated,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: AppTypography.labelSmall(
                      color: AppColors.burgundy,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CoverageRing extends StatelessWidget {
  const _CoverageRing({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : filled / total;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            backgroundColor: AppColors.border,
            color: filled == total
                ? const Color(0xFF2E7D32)
                : AppColors.goldDark,
          ),
          Text(
            '$filled/$total',
            style: AppTypography.labelSmall(
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MilestonesTrack extends StatelessWidget {
  const _MilestonesTrack({
    required this.milestones,
    required this.profile,
    required this.canPublish,
    required this.onPublish,
  });

  final List<HermandadSeasonActMilestone> milestones;
  final HermandadSeasonProfile profile;
  final bool canPublish;
  final ValueChanged<HermandadSeasonActKind> onPublish;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    for (var i = 0; i < milestones.length - 1; i++)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: milestones[i].isFilled &&
                                  milestones[i + 1].isFilled
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.45)
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  for (final milestone in milestones)
                    Expanded(
                      child: Center(
                        child: _MilestoneDot(
                          milestone: milestone,
                          canPublish: canPublish,
                          onPublish: () => onPublish(milestone.kind),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final milestone in milestones)
              Expanded(
                child: _MilestoneLabels(
                  milestone: milestone,
                  profile: profile,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MilestoneDot extends StatelessWidget {
  const _MilestoneDot({
    required this.milestone,
    required this.canPublish,
    required this.onPublish,
  });

  final HermandadSeasonActMilestone milestone;
  final bool canPublish;
  final VoidCallback onPublish;

  Color get _dotColor => switch (milestone.status) {
    HermandadSeasonActStatus.empty => AppColors.textMuted,
    HermandadSeasonActStatus.upcoming => AppColors.goldDark,
    HermandadSeasonActStatus.done => const Color(0xFF2E7D32),
    HermandadSeasonActStatus.mixed => AppColors.burgundy,
  };

  IconData get _icon => switch (milestone.kind) {
    HermandadSeasonActKind.iguala => Icons.handshake_outlined,
    HermandadSeasonActKind.ensayos => Icons.groups_outlined,
    HermandadSeasonActKind.muda => Icons.swap_horiz_outlined,
    HermandadSeasonActKind.desarma => Icons.inventory_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final empty = milestone.status == HermandadSeasonActStatus.empty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: empty && canPublish ? onPublish : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: empty
                ? AppColors.backgroundElevated
                : _dotColor.withValues(alpha: 0.12),
            border: Border.all(
              color: empty ? AppColors.border : _dotColor,
              width: 1.6,
            ),
          ),
          child: Icon(
            empty && canPublish ? Icons.add : _icon,
            size: 15,
            color: empty ? AppColors.textMuted : _dotColor,
          ),
        ),
      ),
    );
  }
}

class _MilestoneLabels extends StatelessWidget {
  const _MilestoneLabels({
    required this.milestone,
    required this.profile,
  });

  final HermandadSeasonActMilestone milestone;
  final HermandadSeasonProfile profile;

  @override
  Widget build(BuildContext context) {
    final empty = milestone.status == HermandadSeasonActStatus.empty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Text(
            milestone.kind.shortLabelFor(profile),
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall(
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            milestone.statusLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall(
              color: empty ? AppColors.textMuted : AppColors.textSecondary,
            ).copyWith(fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}
