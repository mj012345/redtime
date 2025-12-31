import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';

class SymptomChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SymptomChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = selected ? AppColors.primaryLight : Colors.white;
    final borderColor = selected ? AppColors.primary : AppColors.border;
    final textColor = selected ? AppColors.primary : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('symptom_$label'),
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(30),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.shadowChip,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: textColor)),
        ),
      ),
    );
  }
}

