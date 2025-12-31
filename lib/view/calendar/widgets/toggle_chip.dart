import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';

class ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ToggleChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = selected ? AppColors.primary : AppColors.background;
    final borderColor = selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3);
    final textColor = selected ? Colors.white : AppColors.textSecondary;
    final iconBg = selected ? Colors.white.withValues(alpha: 0.2) : AppColors.primaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: textColor),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

