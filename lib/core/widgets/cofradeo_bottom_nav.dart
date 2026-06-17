import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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

  static const _items = [
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendario'),
    _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Foros'),
    _NavItem(Icons.search, Icons.search, 'Buscar'),
    _NavItem(Icons.notifications_outlined, Icons.notifications, 'Notificaciones'),
    _NavItem(Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBarBackground,
        border: Border(
          top: BorderSide(color: AppColors.burgundyDark, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = index == currentIndex;
              final showDot = (index == 0 && showCalendarDot && !isSelected) ||
                  (index == 3 && showNotificationsDot && !isSelected);
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.burgundy
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected
                                  ? AppColors.goldPale
                                  : AppColors.navInactive,
                              size: 22,
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: AppTypography.labelSmall(
                          color: isSelected
                              ? AppColors.goldPale
                              : AppColors.navInactive,
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
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
