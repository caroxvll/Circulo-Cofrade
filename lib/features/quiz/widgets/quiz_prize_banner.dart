import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../models/quiz_models.dart';
import '../quiz_provider.dart';

/// Premio del mes dentro de Pregunta en vivo.
class QuizPrizeBanner extends ConsumerWidget {
  const QuizPrizeBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showcase = ref.watch(quizPrizeShowcaseProvider).asData?.value;
    if (showcase == null || showcase.isEmpty) return const SizedBox.shrink();

    if (compact) {
      final prize = showcase.showClaim
          ? showcase.claimPrize!
          : showcase.stake!;
      final claim = showcase.showClaim;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: AppColors.burgundyDark,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/quiz/ranking'),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _PrizePhoto(url: prize.imageUrl, size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim ? 'TU PREMIO' : 'PREMIO DEL MES',
                          style: AppTypography.labelSmall(color: AppColors.gold)
                              .copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          prize.title.trim().isEmpty
                              ? prize.sponsorName
                              : prize.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.hermandadName(
                            color: AppColors.goldPale,
                          ).copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.gold),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          if (showcase.showClaim)
            _ClaimCard(prize: showcase.claimPrize!, me: showcase.claimMe!),
          if (showcase.showClaim && showcase.showStake)
            const SizedBox(height: 12),
          if (showcase.showStake) _StakeCard(prize: showcase.stake!),
        ],
      ),
    );
  }
}

class _PrizePhoto extends StatelessWidget {
  const _PrizePhoto({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: trimmed.isEmpty
            ? const ColoredBox(
                color: Color(0xFF3A1016),
                child: Icon(Icons.storefront_outlined, color: AppColors.gold),
              )
            : CofradeoNetworkImage(
                url: trimmed,
                fit: BoxFit.cover,
                errorWidget: const ColoredBox(
                  color: Color(0xFF3A1016),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: AppColors.gold,
                  ),
                ),
              ),
      ),
    );
  }
}

class _StakeCard extends StatelessWidget {
  const _StakeCard({required this.prize});

  final QuizPrize prize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF02A0710),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((prize.imageUrl ?? '').trim().isNotEmpty)
            SizedBox(
              height: 132,
              child: CofradeoNetworkImage(
                url: prize.imageUrl!.trim(),
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREMIO DE ${prize.monthLabel.toUpperCase()}',
                  style: AppTypography.labelSmall(color: AppColors.gold)
                      .copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prize.title.trim().isEmpty ? prize.sponsorName : prize.title,
                  style: AppTypography.hermandadName(color: AppColors.goldPale)
                      .copyWith(fontSize: 20),
                ),
                if (prize.sponsorName.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    prize.sponsorName,
                    style: AppTypography.bodyMedium(color: AppColors.goldPale),
                  ),
                ],
                if (prize.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    prize.description,
                    style: AppTypography.bodyMedium(color: AppColors.goldPale),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Lo gana quien cierre ${prize.monthLabel} en primer puesto.',
                  style: AppTypography.labelSmall(color: AppColors.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.prize, required this.me});

  final QuizPrize prize;
  final QuizLeaderboardEntry me;

  @override
  Widget build(BuildContext context) {
    final name = me.displayName.trim().isEmpty ? '@${me.handle}' : me.displayName;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold, width: 1.4),
        color: const Color(0xF23A1016),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((prize.imageUrl ?? '').trim().isNotEmpty)
            SizedBox(
              height: 140,
              child: CofradeoNetworkImage(
                url: prize.imageUrl!.trim(),
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU PREMIO · ${prize.monthLabel.toUpperCase()}',
                  style: AppTypography.labelSmall(color: AppColors.gold)
                      .copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prize.title.trim().isEmpty ? prize.sponsorName : prize.title,
                  style: AppTypography.hermandadName(color: AppColors.goldPale)
                      .copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  '$name · 1.º · ${me.points} pts',
                  style: AppTypography.bodyMedium(color: AppColors.goldPale)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ábrelo en el local, con la sesión iniciada. '
                  'No vale una captura.',
                  style: AppTypography.bodyMedium(color: AppColors.goldPale),
                ),
                if (prize.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    prize.address,
                    style: AppTypography.labelSmall(color: AppColors.gold),
                  ),
                ],
                if (prize.claimUntil != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Recógelo hasta el ${prize.claimUntil!.day}/'
                    '${prize.claimUntil!.month}/${prize.claimUntil!.year}.',
                    style: AppTypography.labelSmall(color: AppColors.gold),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
