import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_decode_cache.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../auth/auth_provider.dart';
import '../models/quiz_models.dart';
import '../quiz_provider.dart';

/// Ranking mensual estilo marcador, con el mismo fondo atmosférico del login.
class QuizRankingScreen extends ConsumerWidget {
  const QuizRankingScreen({super.key});

  static const _filterOrder = [
    QuizRankingMode.top,
    QuizRankingMode.around,
    QuizRankingMode.above,
    QuizRankingMode.below,
  ];

  static String _monthTitle(String yearMonth) {
    final parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    const names = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final y = parts[0];
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return yearMonth;
    return '${names[m - 1]} $y';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveVisible =
        ref.watch(quizLiveVisibleProvider).asData?.value ?? true;
    if (!liveVisible) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Ranking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pregunta en vivo no disponible',
                  style: AppTypography.displaySmall(color: AppColors.burgundy)
                      .copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'El ranking también está desactivado por ahora.',
                  style: AppTypography.bodyMedium(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mode = ref.watch(quizRankingModeProvider);
    final boardAsync = ref.watch(quizMonthlyRankingBundleProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      backgroundColor: AppColors.burgundyDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.gold,
        iconTheme: const IconThemeData(color: AppColors.gold),
        title: Text(
          'Ranking',
          style: AppTypography.screenAppBarTitle(color: AppColors.goldPale),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            cacheWidth: ImageDecodeCache.px(
              context,
              MediaQuery.sizeOf(context).width,
            ),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(color: Color(0xFF5A101A)),
            ),
          ),
          // Veladura suave para legibilidad (sin look neón)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC2A0710),
                  Color(0x992A0710),
                  Color(0xB32A0710),
                ],
              ),
            ),
          ),
          boardAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el ranking.\n'
                  '¿Ejecutaste quiz_ranking_views.sql?\n\n$e',
                  style: AppTypography.bodyMedium(color: AppColors.goldPale),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (bundle) {
              final monthLabel = _monthTitle(bundle.yearMonth);
              final me = bundle.me;
              final showPodium = mode == QuizRankingMode.top &&
                  bundle.entries.any((e) => e.rank <= 3);
              final listEntries = showPodium
                  ? bundle.entries.where((e) => e.rank > 3).toList()
                  : bundle.entries;

              return RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.burgundyDark,
                onRefresh: () async {
                  ref.invalidate(quizMonthlyRankingBundleProvider);
                  await ref.read(quizMonthlyRankingBundleProvider.future);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TEMPORADA',
                                          style: AppTypography.labelSmall(
                                            color: AppColors.gold,
                                          ).copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.3,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          monthLabel,
                                          style: AppTypography.displaySmall(
                                            color: AppColors.goldPale,
                                          ).copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatPill(
                                    icon: Icons.groups_rounded,
                                    label: '${bundle.totalPlayers}',
                                    caption: 'jugadores',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (me != null)
                                _PlayerHud(
                                  entry: me,
                                  total: bundle.totalPlayers,
                                )
                              else if (bundle.totalPlayers > 0)
                                _GameHint(
                                  text:
                                      'Juega la pregunta en vivo para entrar '
                                      'en la clasificación de $monthLabel.',
                                ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _filterOrder.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final m = _filterOrder[i];
                                    return _GameTab(
                                      label: m.label,
                                      selected: mode == m,
                                      onTap: () => ref
                                          .read(
                                            quizRankingModeProvider.notifier,
                                          )
                                          .setMode(m),
                                    );
                                  },
                                ),
                              ),
                              if (showPodium) ...[
                                const SizedBox(height: 16),
                                _GamePodium(
                                  entries: bundle.entries
                                      .where((e) => e.rank <= 3)
                                      .toList(),
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (listEntries.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.25),
                                        thickness: 0.6,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'CLASIFICACIÓN',
                                        style: AppTypography.labelSmall(
                                          color: AppColors.gold,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.6,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.25),
                                        thickness: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (bundle.entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              mode == QuizRankingMode.above
                                  ? 'Nadie por encima.\n¡Vas líder!'
                                  : mode == QuizRankingMode.below
                                      ? 'Nadie por debajo todavía.'
                                      : 'Temporada vacía.\n¡Sé el primero en anotar!',
                              style: AppTypography.bodyLarge(
                                color: AppColors.goldPale,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else if (listEntries.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                        sliver: SliverList.separated(
                          itemCount: listEntries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final e = listEntries[index];
                            final isMe = myId != null && e.userId == myId;
                            return _ScoreboardRow(
                              entry: e,
                              highlight: isMe,
                            );
                          },
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC1A0508),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.titleLarge(color: AppColors.goldPale)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                caption,
                style: AppTypography.labelSmall(color: AppColors.goldLight)
                    .copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerHud extends StatelessWidget {
  const _PlayerHud({required this.entry, required this.total});

  final QuizLeaderboardEntry entry;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct =
        total <= 0 ? 0.0 : (1 - ((entry.rank - 1) / total)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xD91A0508),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RankBadge(rank: entry.rank, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TU MARCADOR',
                      style: AppTypography.labelSmall(color: AppColors.gold)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Puesto #${entry.rank}',
                      style: AppTypography.titleLarge(color: AppColors.goldPale)
                          .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    Text(
                      'de $total · ${entry.correctCount}/${entry.answersCount} aciertos',
                      style: AppTypography.labelSmall(
                        color: AppColors.goldLight,
                      ),
                    ),
                  ],
                ),
              ),
              _PtsChip(points: entry.points, large: true),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 0.6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.gold.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.rank == 1
                  ? '¡Lideras la temporada!'
                  : 'Progreso hacia el podio',
              style: AppTypography.labelSmall(color: AppColors.goldLight)
                  .copyWith(fontSize: 10, letterSpacing: 0.2),
            ),
          ),
          if (entry.rank > 1) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                color: AppColors.gold.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameHint extends StatelessWidget {
  const _GameHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xD91A0508),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sports_esports_rounded,
              color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium(color: AppColors.goldLight),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTab extends StatelessWidget {
  const _GameTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : const Color(0xCC1A0508),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSmall(
              color: selected ? const Color(0xFF2A0710) : AppColors.goldPale,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _GamePodium extends StatelessWidget {
  const _GamePodium({required this.entries});

  final List<QuizLeaderboardEntry> entries;

  QuizLeaderboardEntry? _at(int rank) {
    for (final e in entries) {
      if (e.rank == rank) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xD91A0508),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              Text(
                'PODIO DEL MES',
                style: AppTypography.labelSmall(color: AppColors.gold).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PodiumTower(
                  entry: _at(2),
                  rank: 2,
                  towerHeight: 64,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PodiumTower(
                  entry: _at(1),
                  rank: 1,
                  towerHeight: 88,
                  crowned: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PodiumTower(
                  entry: _at(3),
                  rank: 3,
                  towerHeight: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumTower extends StatelessWidget {
  const _PodiumTower({
    required this.entry,
    required this.rank,
    required this.towerHeight,
    this.crowned = false,
  });

  final QuizLeaderboardEntry? entry;
  final int rank;
  final double towerHeight;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    final medal = _medalFor(rank);
    return Column(
      children: [
        if (crowned)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.gold,
              size: 22,
            ),
          ),
        if (entry != null) ...[
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: medal.color, width: 2),
                ),
                child: CofradeoAvatar(
                  imageUrl: entry!.avatarUrl,
                  size: crowned ? 56 : 46,
                ),
              ),
              Positioned(
                bottom: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: medal.color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '#$rank',
                    style: AppTypography.labelSmall(color: Colors.white)
                        .copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry!.displayName,
            style: AppTypography.labelSmall(color: AppColors.goldPale)
                .copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            '${entry!.points} pts',
            style: AppTypography.labelSmall(color: AppColors.gold).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          Container(
            width: crowned ? 56 : 46,
            height: crowned ? 56 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: medal.color.withValues(alpha: 0.45),
                width: 1.5,
              ),
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.gold.withValues(alpha: 0.45),
              size: crowned ? 26 : 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Vacante',
            style: AppTypography.labelSmall(
              color: AppColors.gold.withValues(alpha: 0.45),
            ),
          ),
          Text(
            '—',
            style: AppTypography.labelSmall(
              color: AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: towerHeight,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: medal.color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: medal.color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$rankº',
            style: AppTypography.displaySmall(color: AppColors.goldPale)
                .copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PtsChip extends StatelessWidget {
  const _PtsChip({required this.points, this.large = false});

  final int points;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 9,
        vertical: large ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            '$points',
            style: (large
                    ? AppTypography.displaySmall(color: AppColors.gold)
                    : AppTypography.titleLarge(color: AppColors.gold))
                .copyWith(
              fontWeight: FontWeight.w800,
              fontSize: large ? 22 : 15,
              height: 1,
            ),
          ),
          Text(
            'PTS',
            style: AppTypography.labelSmall(color: AppColors.goldLight)
                .copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalStyle {
  const _MedalStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}

_MedalStyle _medalFor(int rank) {
  return switch (rank) {
    1 => const _MedalStyle(Color(0xFFC9A227), Icons.emoji_events_rounded),
    2 => const _MedalStyle(Color(0xFF9AA3B2), Icons.military_tech_rounded),
    3 => const _MedalStyle(Color(0xFFB87333), Icons.workspace_premium_rounded),
    _ => const _MedalStyle(AppColors.goldDark, Icons.star_rounded),
  };
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, this.size = 40});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (rank >= 1 && rank <= 3) {
      final medal = _medalFor(rank);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: medal.color,
          shape: BoxShape.circle,
        ),
        child: Icon(medal.icon, color: Colors.white, size: size * 0.48),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x331A0508),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        '#$rank',
        style: AppTypography.titleLarge(color: AppColors.goldPale)
            .copyWith(fontWeight: FontWeight.w800, fontSize: size * 0.28),
      ),
    );
  }
}

class _ScoreboardRow extends StatelessWidget {
  const _ScoreboardRow({required this.entry, required this.highlight});

  final QuizLeaderboardEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final top = entry.rank <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xE62A0A12)
            : const Color(0xCC1A0508),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppColors.gold.withValues(alpha: 0.65)
              : (top
                  ? AppColors.gold.withValues(alpha: 0.4)
                  : AppColors.gold.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank, size: 38),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: highlight ? 0.55 : 0.28),
              ),
            ),
            child: CofradeoAvatar(imageUrl: entry.avatarUrl, size: 36),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: AppTypography.titleLarge(
                          color: AppColors.goldPale,
                        ).copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (highlight) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Text(
                          'TÚ',
                          style: AppTypography.labelSmall(
                            color: AppColors.gold,
                          ).copyWith(fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${entry.handle} · ${entry.correctCount}/${entry.answersCount} aciertos',
                  style: AppTypography.labelSmall(
                    color: AppColors.goldLight.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.points}',
                style: AppTypography.displaySmall(color: AppColors.gold)
                    .copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              Text(
                'pts',
                style: AppTypography.labelSmall(
                  color: AppColors.gold.withValues(alpha: 0.7),
                ).copyWith(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
