import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Asa superior del bottom sheet (arrastrar para cerrar).
class ForumComposeSheetDragHandle extends StatelessWidget {
  const ForumComposeSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class ForumComposeSheetCloseButton extends StatelessWidget {
  const ForumComposeSheetCloseButton({
    super.key,
    this.enabled = true,
  });

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? () => Navigator.pop(context) : null,
      tooltip: 'Cerrar',
      icon: const Icon(Icons.close_rounded, color: AppColors.burgundy),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

/// Título de sheet con botón cerrar a la derecha.
class ForumComposeSheetTitleBar extends StatelessWidget {
  const ForumComposeSheetTitleBar({
    super.key,
    required this.title,
    this.closeEnabled = true,
  });

  final Widget title;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        ForumComposeSheetCloseButton(enabled: closeEnabled),
      ],
    );
  }
}
