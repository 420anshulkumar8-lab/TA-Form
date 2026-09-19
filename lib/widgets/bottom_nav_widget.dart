// lib/widgets/bottom_nav_widget.dart
// UI-only bottom navigation bar: Dashboard / Months / Profile.
// `activeIndex` controls which item is highlighted. Tapping currently does
// nothing except (optionally) call onTap — no real navigation wired yet.
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class BottomNavWidget extends StatelessWidget {
  final int activeIndex; // 0 = Dashboard, 1 = Months, 2 = Profile
  final ValueChanged<int>? onTap;

  const BottomNavWidget({
    super.key,
    this.activeIndex = 1,
    this.onTap,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Dashboard'),
    _NavItemData(icon: Icons.calendar_month_rounded, label: 'Months'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == activeIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onTap == null ? null : () => onTap!(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primaryBlue.withOpacity(0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: isActive
                              ? AppTheme.primaryBlue
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppTheme.primaryBlue
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
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

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}
