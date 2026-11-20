import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_logo.dart';
import '../cronicon_brand.dart';

/// Cabecera del sello: Círculo Cofrade · El Cronicón.
class CroniconMasthead extends StatelessWidget {
  const CroniconMasthead({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(size: 36, useIconVariant: true, circular: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                CroniconBrand.imprintLine,
                style: AppTypography.labelSmall(color: AppColors.goldDark)
                    .copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                CroniconBrand.name,
                style: AppTypography.displaySmall().copyWith(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                CroniconBrand.tagline,
                style: AppTypography.bookCaption(color: AppColors.textSecondary)
                    .copyWith(fontSize: 16, height: 1.35),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Cierre de libro: la firma de la casa.
class CroniconColophonMark extends StatelessWidget {
  const CroniconColophonMark({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final gold = onDark ? AppColors.gold : AppColors.goldDark;
    final title = onDark ? AppColors.textOnDark : AppColors.textPrimary;
    return Column(
      children: [
        const AppLogo(
          size: 28,
          useIconVariant: true,
          circular: true,
        ),
        const SizedBox(height: 10),
        Container(width: 36, height: 1, color: gold),
        const SizedBox(height: 10),
        Text(
          CroniconBrand.name,
          textAlign: TextAlign.center,
          style: AppTypography.displaySmall(color: title).copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          CroniconBrand.imprintLine,
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall(color: gold).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
