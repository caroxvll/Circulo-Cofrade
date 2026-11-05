import 'package:flutter/material.dart';

import '../../../core/widgets/cofradeo_bottom_nav.dart';
import 'forum_compose_sheet_header.dart';

/// Contenido de bottom sheet con scroll cuando el teclado o el formulario ocupan mucho.
class ForumComposeSheetLayout extends StatelessWidget {
  const ForumComposeSheetLayout({
    super.key,
    required this.child,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 12, 0),
    this.showDragHandle = true,
  });

  final Widget child;
  final Widget? header;
  final EdgeInsets padding;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: cofradeoSheetMaxHeight(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) const ForumComposeSheetDragHandle(),
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: header,
            ),
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
