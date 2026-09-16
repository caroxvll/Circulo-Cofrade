import '../models/sponsored_ad.dart';

class AdPriorityTier {
  const AdPriorityTier({
    required this.value,
    required this.label,
    required this.hint,
  });

  final int value;
  final String label;
  final String hint;
}

const adPriorityTiers = [
  AdPriorityTier(value: 5, label: 'Baja', hint: 'Aparece de vez en cuando'),
  AdPriorityTier(value: 10, label: 'Normal', hint: 'Equilibrio habitual'),
  AdPriorityTier(value: 25, label: 'Alta', hint: 'Más visible que la media'),
  AdPriorityTier(value: 50, label: 'Premium', hint: 'Prioridad clara'),
  AdPriorityTier(value: 100, label: 'Máxima', hint: 'Máxima exposición'),
];

const adPriorityMin = 1;
const adPriorityMax = 100;
const adPriorityDefault = 10;

AdPriorityTier? adPriorityTierForValue(int value) {
  for (final tier in adPriorityTiers) {
    if (tier.value == value) return tier;
  }
  return null;
}

String adPriorityLabel(int priority) {
  return adPriorityTierForValue(priority)?.label ?? 'Personalizada';
}

bool adForumTargetingOverlaps(String? a, String? b) {
  if (a == null || b == null) return true;
  return a == b;
}

bool adTopicTargetingOverlaps(String? a, String? b) {
  if (a == null || b == null) return true;
  return a == b;
}

bool adIsEligibleForRotation(SponsoredAd ad) {
  return ad.active && ad.currentImpressions < ad.maxImpressions;
}

List<SponsoredAd> competingAdsForPlacement(
  List<SponsoredAd> all, {
  required SponsoredAd ad,
}) {
  return all.where((candidate) {
    if (candidate.id == ad.id) return false;
    if (!adIsEligibleForRotation(candidate)) return false;
    if (candidate.placement != ad.placement) return false;
    if (!adForumTargetingOverlaps(candidate.forumId, ad.forumId)) {
      return false;
    }
    if (!adTopicTargetingOverlaps(candidate.topicId, ad.topicId)) {
      return false;
    }
    return true;
  }).toList();
}

double? adSharePercent(
  SponsoredAd ad,
  List<SponsoredAd> competitors,
) {
  if (!adIsEligibleForRotation(ad)) return 0;

  final pool = [ad, ...competitors];
  final totalPriority = pool.fold<int>(0, (sum, item) => sum + item.priority);
  if (totalPriority <= 0) return null;

  return (ad.priority / totalPriority) * 100;
}

String adSharePercentLabel(double? share) {
  if (share == null) return '—';
  if (share >= 99.95) return '100%';
  if (share < 0.05) return '<1%';
  return '${share.round()}%';
}

String adPrioritySummary({
  required int priority,
  required double? sharePercent,
  required int competitorCount,
}) {
  final tier = adPriorityLabel(priority);
  final share = adSharePercentLabel(sharePercent);

  if (competitorCount == 0) {
    return '$tier · único activo';
  }

  return '$tier · ≈$share cuota';
}
