import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/utils/forum_navigation.dart';
import '../semana_santa_provider.dart';
import '../utils/semana_santa_topic.dart';

/// Chip de Semana Santa en directo (solo si el gate está abierto).
///
/// [inline]: para el hero junto a Buscar. Si no, queda flotante (legacy).
class SemanaSantaForumsLiveChip extends ConsumerWidget {
  const SemanaSantaForumsLiveChip({
    super.key,
    this.inline = false,
  });

  final bool inline;

  static const _forumId = 'foro-cofradiero';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    if (gate?.isOpen != true) return const SizedBox.shrink();

    ref.watch(ssLiveRealtimeProvider);
    final stats = ref.watch(ssLiveStatsProvider);
    final avisos = stats.total;
    final subtitle = avisos > 0
        ? (avisos == 1 ? '1 aviso' : '$avisos avisos')
        : 'En directo';

    final chip = _LiveChipBody(
      subtitle: subtitle,
      compact: inline,
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
    );

    if (inline) return chip;

    final top = MediaQuery.paddingOf(context).top + 52;
    return Positioned(
      top: top,
      right: 12,
      child: chip,
    );
  }
}

class _LiveChipBody extends StatelessWidget {
  const _LiveChipBody({
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: compact ? 3 : 6,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                AppColors.burgundyDark,
                AppColors.burgundy,
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            compact ? 9 : 10,
            compact ? 7 : 8,
            compact ? 8 : 12,
            compact ? 7 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 6 : 7,
                height: compact ? 6 : 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF7CFFB2),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: compact ? 6 : 7),
              if (compact)
                Text(
                  'Directo',
                  style: AppTypography.labelSmall(color: Colors.white).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                    height: 1,
                  ),
                )
              else
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
                      subtitle,
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
              SizedBox(width: compact ? 2 : 4),
              Icon(
                Icons.chevron_right_rounded,
                size: compact ? 16 : 18,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
