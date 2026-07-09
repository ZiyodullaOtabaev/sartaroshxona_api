import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sartaroshxona/providers/theme_provider.dart';

class AnimatedNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _NavItem(icon: Icons.home_rounded, label: "Asosiy"),
      _NavItem(icon: Icons.map_rounded, label: "Xarita"),
      _NavItem(icon: Icons.calendar_month_rounded, label: "Navbatlar"),
      _NavItem(icon: Icons.person_rounded, label: "Profil"),
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? colors.surface : Colors.white).withOpacity(0.7),
            border: Border(top: BorderSide(color: colors.primary.withOpacity(0.12))),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (i) {
                final isSelected = i == currentIndex;
                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 16 : 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(colors: [colors.primary.withOpacity(0.18), colors.secondary.withOpacity(0.12)])
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected ? Border.all(color: colors.primary.withOpacity(0.3)) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          color: isSelected ? colors.primary : colors.textTertiary,
                          size: 22,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            items[i].label,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}
