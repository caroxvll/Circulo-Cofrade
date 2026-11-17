import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/screen_title_row.dart';
import '../../../core/widgets/search_quick_access_button.dart';
import '../../../shared/models/forum.dart';
import 'noticias_follow_button.dart';

/// Cabecera editorial de Noticias: título, antetítulo y subtítulo, sin foto.
class NoticiasMasthead extends StatelessWidget {
  const NoticiasMasthead({super.key, required this.forum});

  final ForumCategory forum;

  @override
  Widget build(BuildContext context) {
    final description = forum.description.trim();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AdaptiveScreenTitle(
                    text: forum.name.toUpperCase(),
                    style: AppTypography.screenTitle().copyWith(
                      fontSize: 28,
                      letterSpacing: 0.4,
                      height: 1,
                    ),
                  ),
                ),
                const SearchQuickAccessButton(iconColor: AppColors.textPrimary),
                const NoticiasFollowButton(iconOnly: true),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'ACTUALIDAD COFRADE',
                style: AppTypography.labelSmall(color: AppColors.burgundy)
                    .copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.35,
                  height: 1.1,
                ),
              ),
            ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  description,
                  style: AppTypography.bodyMedium(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 13.5, height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
