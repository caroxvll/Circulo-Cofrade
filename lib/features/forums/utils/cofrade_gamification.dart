import '../constants/cofrade_ranks.dart';
import '../constants/cofrade_trophies.dart';

/// Evalúa trofeos desbloqueados a partir de métricas del foro.
List<CofradeTrophy> unlockedTrophies(CofradeForumStats stats) {
  return [
    for (final trophy in CofradeTrophies.all)
      if (stats.meets(trophy.rule)) trophy,
  ];
}

/// Suma de puntos de trofeos conseguidos (cada trofeo cuenta una vez).
int trophyPointsFromStats(CofradeForumStats stats) {
  return unlockedTrophies(stats)
      .fold<int>(0, (sum, trophy) => sum + trophy.points);
}

/// Suma de puntos a partir de ids de trofeos ya persistidos en backend.
int trophyPointsFromIds(Iterable<String> trophyIds) {
  var total = 0;
  for (final id in trophyIds) {
    total += CofradeTrophies.byId(id)?.points ?? 0;
  }
  return total;
}

CofradeRank cofradeRankForPoints(int points) {
  CofradeRank current = CofradeRanks.ladder.first;
  for (final rank in CofradeRanks.ladder) {
    if (points >= rank.minPoints) {
      current = rank;
    } else {
      break;
    }
  }
  return current;
}

/// Rangos ya alcanzados (histórico). No incluye rangos futuros bloqueados.
List<CofradeRank> achievedCofradeRanks(int points) {
  return [
    for (final rank in CofradeRanks.ladder)
      if (points >= rank.minPoints) rank,
  ];
}

CofradeRank cofradeRankFromStats(CofradeForumStats stats) {
  return cofradeRankForPoints(trophyPointsFromStats(stats));
}

CofradeRank? nextCofradeRank(CofradeRank current) {
  final index = CofradeRanks.ladder.indexWhere((r) => r.level == current.level);
  if (index < 0 || index >= CofradeRanks.ladder.length - 1) return null;
  return CofradeRanks.ladder[index + 1];
}

/// Progreso hacia trofeos bloqueados (solo uso interno / futuras notificaciones).
List<CofradeTrophyProgress> nearestTrophyProgress(
  CofradeForumStats stats, {
  int limit = 3,
}) {
  final unlocked = unlockedTrophies(stats).map((t) => t.id).toSet();
  final pending = [
    for (final trophy in CofradeTrophies.all)
      if (!unlocked.contains(trophy.id))
        CofradeTrophyProgress(
          trophy: trophy,
          current: stats.statFor(trophy.rule.kind),
          target: trophy.rule.threshold,
        ),
  ]..sort((a, b) {
      final deficitCompare = a.deficit.compareTo(b.deficit);
      if (deficitCompare != 0) return deficitCompare;
      return a.trophy.points.compareTo(b.trophy.points);
    });

  if (pending.length <= limit) return pending;
  return pending.sublist(0, limit);
}

final class CofradeTrophyProgress {
  const CofradeTrophyProgress({
    required this.trophy,
    required this.current,
    required this.target,
  });

  final CofradeTrophy trophy;
  final int current;
  final int target;

  int get deficit => (target - current).clamp(0, target);

  double get progress =>
      target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// Etiqueta de progreso hacia el siguiente rango (no se muestra en UI pública).
String? nextRankProgressLabel(int points) {
  final rank = cofradeRankForPoints(points);
  final next = nextCofradeRank(rank);
  if (next == null) return null;
  final remaining = next.minPoints - points;
  if (remaining <= 0) return null;
  return 'Te faltan $remaining pts para ${next.title}';
}

String cofradeRankTitleForPoints(int points) =>
    cofradeRankForPoints(points).title;

bool isValidForumReplyContent(String content) {
  return content.trim().length >= CofradeTrophies.minValidReplyLength;
}
