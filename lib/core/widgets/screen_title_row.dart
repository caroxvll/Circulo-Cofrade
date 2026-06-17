import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'calendar_quick_access_button.dart';

/// Cabecera de pantallas secundarias: título serif + atajo al calendario.
class ScreenTitleRow extends StatelessWidget {
  const ScreenTitleRow({
    super.key,
    required this.title,
    this.trailing = const [],
  });

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(title, style: AppTypography.displayLarge()),
        ),
        const CalendarQuickAccessButton(),
        ...trailing,
      ],
    );
  }
}
