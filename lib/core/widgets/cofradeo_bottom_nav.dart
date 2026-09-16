import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Altura del contenido de la barra (icono + etiqueta + padding), sin safe area.
const cofradeoBottomNavContentHeight = 59.0;

/// Posiciona FABs por encima de la barra inferior redondeada del shell.
class CofradeoFabLocation extends FloatingActionButtonLocation {
  const CofradeoFabLocation({this.margin = 16});

  final double margin;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final x = scaffoldGeometry.scaffoldSize.width - fabSize.width - margin;
    final y = scaffoldGeometry.scaffoldSize.height -
        fabSize.height -
        margin -
        cofradeoBottomNavContentHeight -
        scaffoldGeometry.minInsets.bottom;
    return Offset(x, y);
  }
}

double cofradeoBottomScrollPadding(BuildContext context, {double extra = 80}) {
  return MediaQuery.paddingOf(context).bottom +
      cofradeoBottomNavContentHeight +
      extra;
}

/// Espacio bajo modales cuando el shell muestra la barra inferior fija.
double cofradeoShellBottomInset(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom + cofradeoBottomNavContentHeight;
}

/// Padding inferior de bottom sheets: margen + teclado + barra del shell.
double cofradeoSheetBottomPadding(
  BuildContext context, {
  double extra = 16,
}) {
  return extra +
      MediaQuery.viewInsetsOf(context).bottom +
      cofradeoShellBottomInset(context);
}

class CofradeoBottomNav extends StatelessWidget {
  const CofradeoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showCalendarDot = false,
    this.showNotificationsDot = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showCalendarDot;
  final bool showNotificationsDot;

  static const _topRadius = 22.0;

  static const _items = [
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendario'),
    _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Foros'),
    _NavItem(Icons.search, Icons.search, 'Buscar'),
    _NavItem(
      Icons.notifications_outlined,
      Icons.notifications,
      'Notificaciones',
    ),
    _NavItem(Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navBarBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_topRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_topRadius),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final isSelected = index == currentIndex;
                final showDot =
                    (index == 0 && showCalendarDot && !isSelected) ||
                    (index == 3 && showNotificationsDot && !isSelected);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected
                                  ? AppColors.burgundy
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                            if (showDot)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: SizedBox(
                            height: 13,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSmall(
                                  color: isSelected
                                      ? AppColors.burgundy
                                      : AppColors.textMuted,
                                ).copyWith(
                                  fontSize: 10.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
