import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/forum.dart';
import '../forum_topics_typography.dart';

/// Badge compacto para el listado de temas (cerrado / resuelto).
class TopicStatusBadge extends StatelessWidget {
  const TopicStatusBadge({super.key, required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    final status = topic.listStatusBadge;
    if (status == null) return const SizedBox.shrink();
    return _TopicStatusChip(status: status);
  }
}

/// Banner premium en el detalle del hilo.
class TopicClosedBanner extends StatelessWidget {
  const TopicClosedBanner({super.key, required this.topic});

  final ForumTopic topic;

  @override
  Widget build(BuildContext context) {
    if (!topic.isClosed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0E4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldDark.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: AppColors.goldDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hilo cerrado',
                  style: ForumTopicsTypography.style(
                    color: AppColors.goldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ya no admite respuestas nuevas. Puedes leer el contenido '
                  'y la conversación previa.',
                  style: ForumTopicsTypography.style(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum TopicListStatusBadge { closed, resolved }

extension ForumTopicListStatus on ForumTopic {
  TopicListStatusBadge? get listStatusBadge {
    if (isClosed) return TopicListStatusBadge.closed;
    if (isResolved) return TopicListStatusBadge.resolved;
    return null;
  }

  bool get isArchivedInList => isClosed || isResolved;
}

class _TopicStatusChip extends StatelessWidget {
  const _TopicStatusChip({required this.status});

  final TopicListStatusBadge status;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, icon, label) = switch (status) {
      TopicListStatusBadge.closed => (
        const Color(0xFFF3EBD8),
        AppColors.goldLight.withValues(alpha: 0.95),
        AppColors.goldDark,
        Icons.lock_outline_rounded,
        'Cerrado',
      ),
      TopicListStatusBadge.resolved => (
        const Color(0xFFE6EFE3),
        const Color(0xFFC5D8BE),
        const Color(0xFF3D6B45),
        Icons.check_circle_outline_rounded,
        'Resuelto',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: ForumTopicsTypography.card(
              color: fg,
              fontWeight: FontWeight.w700,
            ).copyWith(letterSpacing: 0.15),
          ),
        ],
      ),
    );
  }
}
