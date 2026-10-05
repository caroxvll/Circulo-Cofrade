import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../profile/profile_design.dart';
import '../constants/cofrade_ranks.dart';
import '../utils/cofrade_gamification.dart';

/// Máximo de rangos visibles a la vez (el resto va por páginas).
const _rankPageSize = 5;

/// Histórico de rangos cofrades conseguidos (sin mostrar los futuros).
/// Si hay muchos, se pagina para que quepa en pantalla.
class ProfileCofradeRankHistory extends StatefulWidget {
  const ProfileCofradeRankHistory({
    super.key,
    required this.profile,
    this.compact = false,
    this.fillHeight = false,
  });

  final UserProfile profile;
  final bool compact;
  final bool fillHeight;

  @override
  State<ProfileCofradeRankHistory> createState() =>
      _ProfileCofradeRankHistoryState();
}

class _ProfileCofradeRankHistoryState extends State<ProfileCofradeRankHistory> {
  int? _pageIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.profile.trophyPoints <= 0) return const SizedBox.shrink();

    final achieved = achievedCofradeRanks(widget.profile.trophyPoints);
    if (achieved.length <= 1) return const SizedBox.shrink();

    final current = cofradeRankForPoints(widget.profile.trophyPoints);
    final pageCount =
        ((achieved.length + _rankPageSize - 1) ~/ _rankPageSize);
    // Por defecto la última página (donde está el rango Actual).
    final lastPage = pageCount - 1;
    final pageIndex = (_pageIndex ?? lastPage).clamp(0, lastPage);
    final start = pageIndex * _rankPageSize;
    final pageRanks = achieved.skip(start).take(_rankPageSize).toList();

    final pad = widget.compact ? 10.0 : 14.0;
    final gap = widget.compact ? 6.0 : 12.0;

    final header = Row(
      children: [
        Icon(
          Icons.timeline,
          size: widget.compact ? 15 : 17,
          color: AppColors.goldDark,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Trayectoria cofrade',
            style: ProfileDesign.meta().copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontSize: widget.compact ? 12 : null,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.7),
            ),
          ),
          child: Text(
            '${achieved.length}',
            style: ProfileDesign.meta().copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.burgundy,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );

    final ranksColumn = widget.fillHeight
        ? Expanded(
            child: Column(
              children: [
                for (var i = 0; i < pageRanks.length; i++)
                  Expanded(
                    child: _RankHistoryRow(
                      rank: pageRanks[i],
                      isCurrent: pageRanks[i].level == current.level,
                      isLast: i == pageRanks.length - 1,
                      compact: widget.compact,
                      expand: true,
                    ),
                  ),
              ],
            ),
          )
        : Column(
            children: [
              for (var i = 0; i < pageRanks.length; i++)
                _RankHistoryRow(
                  rank: pageRanks[i],
                  isCurrent: pageRanks[i].level == current.level,
                  isLast: i == pageRanks.length - 1,
                  compact: widget.compact,
                ),
            ],
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: gap),
        ranksColumn,
        if (pageCount > 1) ...[
          SizedBox(height: widget.compact ? 2 : 4),
          _RankPager(
            pageIndex: pageIndex,
            pageCount: pageCount,
            onPageChanged: (page) => setState(() => _pageIndex = page),
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      decoration: ProfileDesign.cardDecoration(),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, widget.compact ? 6 : 10),
      child: body,
    );
  }
}

class _RankPager extends StatelessWidget {
  const _RankPager({
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
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Anterior',
            onPressed: canPrev ? () => onPageChanged(pageIndex - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: AppColors.burgundy,
            disabledColor: AppColors.textMuted.withValues(alpha: 0.35),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text(
            '${pageIndex + 1} / $pageCount',
            style: AppTypography.labelSmall(
              color: AppColors.textSecondary,
            ).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
          IconButton(
            tooltip: 'Siguiente',
            onPressed: canNext ? () => onPageChanged(pageIndex + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: AppColors.burgundy,
            disabledColor: AppColors.textMuted.withValues(alpha: 0.35),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _RankHistoryRow extends StatelessWidget {
  const _RankHistoryRow({
    required this.rank,
    required this.isCurrent,
    required this.isLast,
    this.compact = false,
    this.expand = false,
  });

  final CofradeRank rank;
  final bool isCurrent;
  final bool isLast;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final dotColor = isCurrent
        ? AppColors.burgundy
        : AppColors.goldDark.withValues(alpha: 0.75);
    final lineColor = AppColors.gold.withValues(alpha: 0.35);
    final titleSize = compact ? 12.0 : 13.0;
    final bottomPad = compact ? 4.0 : 10.0;

    final content = Row(
      children: [
        Expanded(
          child: Text(
            rank.title,
            style: AppTypography.bodyMedium(
              color: isCurrent ? AppColors.burgundy : AppColors.textPrimary,
            ).copyWith(
              fontSize: titleSize,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              height: 1.15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.goldPale.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Actual',
              style: AppTypography.labelSmall(
                color: AppColors.goldDark,
              ).copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          Icon(
            Icons.check_rounded,
            size: compact ? 14 : 16,
            color: AppColors.goldDark.withValues(alpha: 0.85),
          ),
      ],
    );

    if (expand) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: isCurrent ? 9 : 7,
                  height: isCurrent ? 9 : 7,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(
                            color: AppColors.gold.withValues(alpha: 0.55),
                            width: 1.2,
                          )
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: content,
            ),
          ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: isCurrent ? 10 : 8,
                  height: isCurrent ? 10 : 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(
                            color: AppColors.gold.withValues(alpha: 0.55),
                            width: 1.5,
                          )
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : bottomPad),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}
