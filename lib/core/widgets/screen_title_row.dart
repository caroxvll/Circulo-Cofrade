import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'calendar_quick_access_button.dart';

/// Cabecera de pantallas secundarias: título serif dorado + atajo al calendario.
class ScreenTitleRow extends StatelessWidget {
  const ScreenTitleRow({
    super.key,
    required this.title,
    this.trailing = const [],
    this.uppercase = true,
  });

  final String title;
  final List<Widget> trailing;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final label = uppercase ? title.toUpperCase() : title;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(label, style: AppTypography.screenTitle()),
        ),
        const CalendarQuickAccessButton(),
        ...trailing,
      ],
    );
  }
}
