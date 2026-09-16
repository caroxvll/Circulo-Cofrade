import 'package:flutter/material.dart';

import '../../../core/widgets/cofradeo_bottom_nav.dart';
import 'forum_compose_sheet_header.dart';

/// Contenido de bottom sheet con scroll cuando el teclado o el formulario ocupan mucho.
class ForumComposeSheetLayout extends StatelessWidget {
  const ForumComposeSheetLayout({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 12, 0),
    this.showDragHandle = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.92 - media.viewInsets.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) const ForumComposeSheetDragHandle(),
          Flexible(
            child: SingleChildScrollView(
              padding: padding.copyWith(
                bottom: cofradeoSheetBottomPadding(context, extra: 12),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
