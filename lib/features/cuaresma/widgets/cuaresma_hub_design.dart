import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../forums/topic_detail_typography.dart';

class CuaresmaHubElevatedCard extends StatelessWidget {
  const CuaresmaHubElevatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class CuaresmaHubNewTopicButton extends StatelessWidget {
  const CuaresmaHubNewTopicButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.burgundy,
        side: const BorderSide(color: AppColors.burgundy, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: Text(
        'Tema',
        style: TopicDetailTypography.body(
          color: AppColors.burgundy,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
    );
  }
}

class CuaresmaHubTextLink extends StatelessWidget {
  const CuaresmaHubTextLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.burgundy,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TopicDetailTypography.meta(
              color: AppColors.burgundy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 16),
        ],
      ),
    );
  }
}

class CuaresmaHubLiveBadge extends StatelessWidget {
  const CuaresmaHubLiveBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.burgundy.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveDot(size: compact ? 6 : 7),
          const SizedBox(width: 5),
          Text(
            'EN DIRECTO',
            style: TopicDetailTypography.meta(
              color: AppColors.burgundy,
              fontWeight: FontWeight.w800,
            ).copyWith(fontSize: compact ? 9.5 : 10, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.burgundy,
        shape: BoxShape.circle,
      ),
    );
  }
}

class CuaresmaHubOutlineButton extends StatelessWidget {
  const CuaresmaHubOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: Icon(icon, size: 15, color: AppColors.burgundy),
      label: Text(
        label,
        style: TopicDetailTypography.meta(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class CuaresmaHubPrimaryPillButton extends StatelessWidget {
  const CuaresmaHubPrimaryPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.burgundy,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 9,
        ),
        minimumSize: Size(0, compact ? 30 : 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TopicDetailTypography.body(
              color: AppColors.textOnDark,
            ).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11.5 : 12.5,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 16),
          ] else
            const Padding(
              padding: EdgeInsets.only(left: 1),
              child: Icon(Icons.chevron_right_rounded, size: 14),
            ),
        ],
      ),
    );
  }
}

class CuaresmaHubStatChip extends StatelessWidget {
  const CuaresmaHubStatChip({
    super.key,
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: highlighted ? AppColors.burgundy : AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TopicDetailTypography.meta(
              color: highlighted ? AppColors.burgundy : AppColors.textSecondary,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
