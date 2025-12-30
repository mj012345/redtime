import 'package:flutter/material.dart';

enum NavTab { calendar, report, my }

class BottomNav extends StatelessWidget {
  final NavTab current;
  final ValueChanged<NavTab> onTap;

  const BottomNav({super.key, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFC),
        border: const Border(top: BorderSide(color: Color(0xFFFFEBEE))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Icons.calendar_month,
                label: '달력',
                selected: current == NavTab.calendar,
                onTap: () => onTap(NavTab.calendar),
              ),
              _NavItem(
                icon: Icons.insights,
                label: '리포트',
                selected: current == NavTab.report,
                onTap: () => onTap(NavTab.report),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'MY',
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
    final color = selected ? const Color(0xFFD32F2F) : const Color(0xFFAAAAAA);
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
            style: TextStyle(
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
