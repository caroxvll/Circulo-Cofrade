import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../profile/profile_design.dart';
import '../constants/cofrade_ranks.dart';
import '../utils/cofrade_gamification.dart';

/// Histórico de rangos cofrades conseguidos (sin mostrar los futuros).
class ProfileCofradeRankHistory extends StatelessWidget {
  const ProfileCofradeRankHistory({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.trophyPoints <= 0) return const SizedBox.shrink();

    final achieved = achievedCofradeRanks(profile.trophyPoints);
    if (achieved.length <= 1) return const SizedBox.shrink();

    final current = cofradeRankForPoints(profile.trophyPoints);

    return Container(
      decoration: ProfileDesign.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 17, color: AppColors.goldDark),
              const SizedBox(width: 8),
              Text(
                'Trayectoria cofrade',
                style: ProfileDesign.meta().copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < achieved.length; i++)
            _RankHistoryRow(
              rank: achieved[i],
              isCurrent: achieved[i].level == current.level,
              isLast: i == achieved.length - 1,
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
  });

  final CofradeRank rank;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = isCurrent
        ? AppColors.burgundy
        : AppColors.goldDark.withValues(alpha: 0.75);
    final lineColor = AppColors.gold.withValues(alpha: 0.35);

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
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rank.title,
                      style: AppTypography.bodyMedium(
                        color: isCurrent
                            ? AppColors.burgundy
                            : AppColors.textPrimary,
                      ).copyWith(
                        fontSize: 13,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
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
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.goldDark.withValues(alpha: 0.85),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
