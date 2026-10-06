import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/utils/forum_navigation.dart';
import '../semana_santa_provider.dart';
import '../utils/semana_santa_topic.dart';

/// Chip flotante (arriba-derecha) solo cuando el en directo de SS está abierto.
class SemanaSantaForumsLiveChip extends ConsumerWidget {
  const SemanaSantaForumsLiveChip({super.key});

  static const _forumId = 'foro-cofradiero';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    if (gate?.isOpen != true) return const SizedBox.shrink();

    ref.watch(ssLiveRealtimeProvider);
    final stats = ref.watch(ssLiveStatsProvider);
    final avisos = stats.total;
    final label = avisos > 0
        ? (avisos == 1 ? '1 aviso' : '$avisos avisos')
        : 'En directo';

    final top = MediaQuery.paddingOf(context).top + 8;

    return Positioned(
      top: top,
      right: 12,
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () {
            prefetchForumTopic(
              ref,
              forumId: _forumId,
              topicId: semanaSantaTopicId,
            );
            // ignore: unused_result
            ref.read(ssLiveRawFeedProvider.future);
            context.push('/foros/$_forumId/tema/$semanaSantaTopicId');
          },
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  AppColors.burgundyDark,
                  AppColors.burgundy,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.burgundyDark.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7CFFB2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SEMANA SANTA',
                      style: AppTypography.labelSmall(
                        color: Colors.white,
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.7,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: AppTypography.labelSmall(
                        color: Colors.white.withValues(alpha: 0.9),
                      ).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
