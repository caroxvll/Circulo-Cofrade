import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'calendar_quick_access_button.dart';

/// Título de pantalla que se encoge (sin cortar ni partir) si el Row no cabe.
///
/// En móviles estrechos o con tamaño de texto del sistema alto, un título
/// largo tipo «CALENDARIO» / «NOTIFICACIONES» junto a iconos se partía o
/// mostraba ellipsis; [FittedBox] lo escala manteniendo una sola línea.
class AdaptiveScreenTitle extends StatelessWidget {
  const AdaptiveScreenTitle({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

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
          child: AdaptiveScreenTitle(
            text: label,
            style: AppTypography.screenTitle(),
          ),
        ),
        const CalendarQuickAccessButton(),
        ...trailing,
      ],
    );
  }
}
