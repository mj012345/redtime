import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';

class SymptomChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback? onMemoTap;

  const SymptomChip({
    super.key,
    required this.label,
    required this.selected,
    this.disabled = false,
    required this.onTap,
    this.onMemoTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = selected
        ? AppColors.primaryLight
        : (disabled ? AppColors.disabled : Colors.white);
    final borderColor = selected
        ? AppColors.primary.withValues(alpha: 0.1)
        : (disabled
              ? AppColors.border.withValues(alpha: 0.5)
              : AppColors.border);
    final textColor = selected
        ? AppColors.primary
        : (disabled
              ? AppColors.textSecondary.withValues(alpha: 0.5)
              : AppColors.textSecondary);
    final isMemo = label == '메모';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('symptom_$label'),
        borderRadius: BorderRadius.circular(30),
        onTap: disabled
            ? null
            : (isMemo && onMemoTap != null ? onMemoTap : onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: textColor)),
              if (isMemo && onMemoTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.edit_note, size: 14, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
