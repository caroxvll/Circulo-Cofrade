import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'hermandad_board_category_tabs.dart';

/// Cabecera anclada con las pestañas del tablón oficial (solo chips).
class HermandadBoardTabsHeader extends StatelessWidget {
  const HermandadBoardTabsHeader({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.newCounts,
    this.boardSubtitle,
    this.elevated = false,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, int> newCounts;
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
          newCounts: newCounts,
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
    required this.newCounts,
    this.boardSubtitle,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, int> newCounts;
  final String? boardSubtitle;

  /// Solo chips de sección.
  static const extent = 48.0;

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
        newCounts: newCounts,
        onSelected: onSelected,
        boardSubtitle: boardSubtitle,
        elevated: overlapsContent || shrinkOffset > 0,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HermandadBoardTabsDelegate oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.newCounts != newCounts ||
        oldDelegate.boardSubtitle != boardSubtitle;
  }
}
