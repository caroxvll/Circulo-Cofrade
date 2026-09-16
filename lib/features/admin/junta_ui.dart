import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Tipografía y espaciado compactos para todo el panel Junta.
abstract final class JuntaUi {
  static const listPadding = EdgeInsets.fromLTRB(16, 8, 16, 24);
  static const cardPadding = EdgeInsets.all(12);
  static const cardRadius = 12.0;
  static const sectionGap = 14.0;
  static const itemGap = 8.0;
  static const iconCircleSize = 36.0;

  static TextStyle shellTitle({Color? color}) =>
      AppTypography.screenAppBarTitle(color: color ?? AppColors.goldDark)
          .copyWith(fontSize: 20, letterSpacing: 0.35, height: 1.05);

  static TextStyle moduleTitle({Color? color}) => _interTextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle sectionTitle({Color? color}) =>
      AppTypography.labelSmall(color: color ?? AppColors.burgundy).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );

  static TextStyle sectionHeader({Color? color}) =>
      AppTypography.labelSmall(color: color ?? AppColors.textMuted).copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  static TextStyle cardTitle({Color? color}) =>
      AppTypography.titleLarge(color: color ?? AppColors.textPrimary).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle body({Color? color}) =>
      AppTypography.bodyMedium(color: color ?? AppColors.textSecondary).copyWith(
        fontSize: 12,
        height: 1.35,
      );

  static TextStyle caption({Color? color}) =>
      AppTypography.labelSmall(color: color ?? AppColors.textMuted).copyWith(
        fontSize: 11,
        height: 1.25,
      );

  static TextStyle emptyTitle({Color? color}) =>
      AppTypography.titleLarge(color: color ?? AppColors.textPrimary).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static TextStyle navLabel({
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
  }) =>
      AppTypography.titleLarge(color: color ?? AppColors.textPrimary).copyWith(
        fontSize: 13,
        fontWeight: fontWeight,
        height: 1.2,
      );

  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
  }) =>
      InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        helperMaxLines: 3,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: const OutlineInputBorder(),
        labelStyle: caption(color: AppColors.textMuted),
      );

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.border),
      );
}

// Evita importar google_fonts en cada sitio; delega en AppTypography.inter base.
TextStyle _interTextStyle({
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
  double? height,
}) =>
    AppTypography.bodyMedium(color: color).copyWith(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );

class JuntaCardTitleBlock extends StatelessWidget {
  const JuntaCardTitleBlock({
    super.key,
    required this.title,
    this.badges = const <Widget>[],
    this.maxLines = 2,
  });

  final String title;
  final List<Widget> badges;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: JuntaUi.cardTitle(),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: badges,
          ),
        ],
      ],
    );
  }
}

class JuntaSectionHeader extends StatelessWidget {
  const JuntaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: JuntaUi.sectionTitle()),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: JuntaUi.body(color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

class JuntaInfoBanner extends StatelessWidget {
  const JuntaInfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: JuntaUi.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.burgundy),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: JuntaUi.body())),
        ],
      ),
    );
  }
}

class JuntaEmptyPanel extends StatelessWidget {
  const JuntaEmptyPanel({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(message, style: JuntaUi.emptyTitle(), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: JuntaUi.body(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
