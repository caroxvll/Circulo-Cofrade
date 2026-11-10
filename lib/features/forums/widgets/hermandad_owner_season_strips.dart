import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../../calendar/utils/holy_week_countdown.dart';
import '../../cuaresma/utils/cuaresma_topic.dart';
import '../../semana_santa/semana_santa_provider.dart';
import '../../semana_santa/utils/semana_santa_topic.dart';
import '../utils/hermandad_board_display.dart';

const _seasonForumId = 'foro-cofradiero';

/// Franjas de Cuaresma y Semana Santa en el tablón de la propia hermandad.
class HermandadOwnerSeasonStrips extends ConsumerWidget {
  const HermandadOwnerSeasonStrips({super.key, required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strips = <Widget>[];
    if (_cuaresmaIsOpen(DateTime.now())) {
      strips.add(
        _SeasonStrip(
          kicker: 'CUARESMA',
          title: 'Ensayos abiertos',
          subtitle: 'Publica el aviso del ensayo de hoy.',
          onTap: () => context.push(
            '/foros/$_seasonForumId/tema/$cuaresmaTopicId',
          ),
        ),
      );
    }

    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    final day = gate?.activeDay;
    final ownDay = parseHermandadTopicTitle(topic.title).processionDay?.trim();
    final ssOpen = gate?.isOpen == true &&
        day != null &&
        day.isOpen &&
        ownDay != null &&
        ownDay.isNotEmpty &&
        ownDay == day.label.trim();
    if (ssOpen) {
      strips.add(
        _SeasonStrip(
          kicker: 'SEMANA SANTA',
          title: 'Hoy sales',
          subtitle: 'Es ${day.label}. Publica el directo de la hermandad.',
          onTap: () => context.push(
            '/foros/$_seasonForumId/tema/$semanaSantaTopicId/informar',
          ),
        ),
      );
    }

    if (strips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (var i = 0; i < strips.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            strips[i],
          ],
        ],
      ),
    );
  }
}

bool _cuaresmaIsOpen(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var palm = palmSunday(today.year);
  final easter = easterSunday(today.year);
  if (today.isAfter(easter)) {
    palm = palmSunday(today.year + 1);
  }
  final ash = addCalendarDays(palm, -39);
  return !today.isBefore(ash) && today.isBefore(palm);
}

class _SeasonStrip extends StatelessWidget {
  const _SeasonStrip({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kicker,
                        style: AppTypography.labelSmall(color: AppColors.goldDark)
                            .copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: AppTypography.hermandadName().copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.burgundy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
