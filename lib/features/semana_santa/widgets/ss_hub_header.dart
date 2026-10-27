import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../forums/topic_detail_typography.dart';

/// Cabecera compacta del hub SS (sin foto hero).
class SemanaSantaHubSummaryCard extends StatelessWidget {
  const SemanaSantaHubSummaryCard({
    super.key,
    required this.onPublish,
    this.liveOpen = true,
    this.canInform = false,
    this.jornadaLabel,
  });

  final VoidCallback onPublish;
  final bool liveOpen;
  final bool canInform;
  final String? jornadaLabel;

  @override
  Widget build(BuildContext context) {
    final day = jornadaLabel?.trim();
    final title = (day != null && day.isNotEmpty) ? day : 'Sin jornada activa';
    final statusLabel = liveOpen
        ? 'En directo'
        : (day != null && day.isNotEmpty ? 'En pausa' : 'Cerrado');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.hermandadName(
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 26, height: 1, letterSpacing: 0),
              ),
            ),
            if (liveOpen) ...[
              const SizedBox(width: 8),
              Text(
                'últimas 12 h',
                style: TopicDetailTypography.meta(
                  color: AppColors.textMuted,
                ).copyWith(fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _HubPill(
              label: statusLabel,
              filled: liveOpen,
              leading: _LiveDot(live: liveOpen),
            ),
            if (liveOpen && canInform) ...[
              const SizedBox(width: 8),
              _HubPill(
                label: 'Informar',
                filled: true,
                onTap: onPublish,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HubPill extends StatelessWidget {
  const _HubPill({
    required this.label,
    required this.filled,
    this.leading,
    this.onTap,
  });

  final String label;
  final bool filled;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Material(
      color: filled ? AppColors.burgundy : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: filled
                  ? AppColors.burgundy
                  : AppColors.gold.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TopicDetailTypography.body(
                  color: filled ? Colors.white : AppColors.textSecondary,
                ).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: live ? const Color(0xFF3DDC97) : AppColors.textMuted,
        shape: BoxShape.circle,
        border: Border.all(
          color: live ? Colors.white : Colors.transparent,
          width: 1.2,
        ),
      ),
    );
  }
}
