import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'hermandad_board_category_tabs.dart';

/// Cabecera anclada con las pestañas del tablón oficial.
class HermandadBoardTabsHeader extends StatelessWidget {
  const HermandadBoardTabsHeader({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.counts,
    this.boardSubtitle,
    this.elevated = false,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;
  final Map<String, int> counts;
  final String? boardSubtitle;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      elevation: elevated ? 2 : 0,
      shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
        child: HermandadBoardCategoryTabs(
          selected: selected,
          counts: counts,
          onSelected: onSelected,
          boardSubtitle: boardSubtitle,
        ),
      ),
    );
  }
}

class HermandadBoardTabsDelegate extends SliverPersistentHeaderDelegate {
  HermandadBoardTabsDelegate({
    required this.selected,
    required this.onSelected,
    required this.counts,
    this.boardSubtitle,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;
  final Map<String, int> counts;
  final String? boardSubtitle;

  /// Título + chips horizontales (escala ForumTopicsTypography).
  static const extent = 86.0;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      child: HermandadBoardTabsHeader(
        selected: selected,
        counts: counts,
        onSelected: onSelected,
        boardSubtitle: boardSubtitle,
        elevated: overlapsContent || shrinkOffset > 0,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HermandadBoardTabsDelegate oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.counts != counts ||
        oldDelegate.boardSubtitle != boardSubtitle;
  }
}
