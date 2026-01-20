import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

enum NavTab { calendar, report, my }

class BottomNav extends StatelessWidget {
  final NavTab current;
  final ValueChanged<NavTab> onTap;

  const BottomNav({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: const Border(top: BorderSide(color: AppColors.primaryLight)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Icons.calendar_month,
                label: 'calendar',
                selected: current == NavTab.calendar,
                onTap: () => onTap(NavTab.calendar),
              ),
              _NavItem(
                icon: Icons.insights,
                label: 'report',
                selected: current == NavTab.report,
                onTap: () => onTap(NavTab.report),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'my',
                selected: current == NavTab.my,
                onTap: () => onTap(NavTab.my),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textDisabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
