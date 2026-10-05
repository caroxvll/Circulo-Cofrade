import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../forums/topic_detail_typography.dart';
import '../../forums/utils/hermandad_board_display.dart';
import '../../forums/utils/hermandad_local_assets.dart';
import '../models/ss_live_update.dart';
import '../semana_santa_provider.dart';
import '../utils/ss_informar_helpers.dart';
import 'ss_live_design.dart';

/// Hermandades que salen hoy: al pulsar filtran el chat en directo.
class SemanaSantaHubHermandadesStrip extends ConsumerWidget {
  const SemanaSantaHubHermandadesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayAsync = ref.watch(ssDayHermandadesProvider);
    final updates = ref.watch(ssLiveRawFeedProvider).asData?.value ?? const [];
    final selected = ref.watch(ssHermandadFilterProvider);
    final gate = ref.watch(ssLiveGateProvider).asData?.value;
    final dayTitle = gate?.activeDay?.label.trim().isNotEmpty == true
        ? gate!.activeDay!.label
        : 'Hoy en la calle';

    return dayAsync.when(
      loading: () => const SizedBox(height: 72),
      error: (_, _) => const SizedBox.shrink(),
      data: (options) {
        if (options.isEmpty) {
          return _EmptyDayCta(
            dayTitle: dayTitle,
            onExplore: () => context.push('/foros/hermandades'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayTitle,
                        style: AppTypography.displaySmall(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected == null
                            ? 'Pulsa una hermandad para filtrar el chat'
                            : 'Filtrado · toca otra o Todas',
                        style: TopicDetailTypography.meta(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (selected != null)
                  TextButton(
                    onPressed: () => ref
                        .read(ssHermandadFilterProvider.notifier)
                        .setHermandad(null),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.burgundy,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Todas ›',
                      style: TopicDetailTypography.meta(
                        color: AppColors.burgundy,
                        fontWeight: FontWeight.w700,
                      ).copyWith(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = selected != null &&
                      selected.toLowerCase() == option.name.toLowerCase();
                  final status = _statusForName(option.name, updates);
                  return _DayCrestChip(
                    option: option,
                    status: status,
                    selected: isSelected,
                    onTap: () {
                      final notifier =
                          ref.read(ssHermandadFilterProvider.notifier);
                      if (isSelected) {
                        notifier.setHermandad(null);
                      } else {
                        notifier.setHermandad(option.name);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

({String label, Color color})? _statusForName(
  String name,
  List<SsLiveUpdate> updates,
) {
  final needle = name.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final u in updates) {
    final label = u.hermandadLabel?.trim().toLowerCase() ?? '';
    if (label.isEmpty) continue;
    if (label == needle || label.contains(needle) || needle.contains(label)) {
      return (label: u.kind.label, color: ssKindColor(u.kind));
    }
  }
  return null;
}

class _DayCrestChip extends StatelessWidget {
  const _DayCrestChip({
    required this.option,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final SsDayHermandadOption option;
  final ({String label, Color color})? status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = hermandadDayAccentColor(option.processionDay);
    final remote = option.iconImageUrl?.trim();
    final hasRemote = remote != null && remote.isNotEmpty;
    final localAvatar = HermandadLocalAssets.avatar(
      processionDay: option.processionDay,
      hermandadName: option.name,
    );
    final dotColor = status?.color ?? const Color(0xFF2F9E6E);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.1),
                    border: Border.all(
                      color: selected
                          ? AppColors.burgundy
                          : AppColors.gold.withValues(alpha: 0.45),
                      width: selected ? 2.2 : 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasRemote
                      ? CofradeoNetworkImage(
                          url: remote,
                          fit: BoxFit.contain,
                          width: 48,
                          height: 48,
                          cacheSize: 96,
                          errorWidget: Icon(
                            Icons.church_outlined,
                            size: 22,
                            color: accent,
                          ),
                        )
                      : localAvatar != null
                          ? Image.asset(localAvatar, fit: BoxFit.cover)
                          : Icon(
                              Icons.church_outlined,
                              size: 22,
                              color: accent,
                            ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: selected ? AppColors.burgundy : AppColors.textPrimary,
              ).copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            Text(
              status?.label ?? 'Sin novedades',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TopicDetailTypography.meta(
                color: status?.color ?? AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ).copyWith(fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDayCta extends StatelessWidget {
  const _EmptyDayCta({required this.dayTitle, required this.onExplore});

  final String dayTitle;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onExplore,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.church_outlined,
                color: AppColors.burgundy,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$dayTitle · aún no hay hermandades listadas',
                  style: TopicDetailTypography.meta(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
