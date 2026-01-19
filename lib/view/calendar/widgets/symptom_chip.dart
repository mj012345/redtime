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
    final isGood = label == '좋음';
    final isMemo = label == '메모';
    
    // 선택된 경우: 좋음은 초록색, 그 외는 보라색
    // 선택되지 않은 경우: 기본 색상
    final fillColor = selected
        ? (isGood ? SymptomColors.goodSymptom.withValues(alpha: 0.3): SymptomColors.symptomBase.withValues(alpha: 0.2))
        : (disabled ? AppColors.disabled : Colors.white);
    
    final borderColor = selected
        ? (isGood 
            ? SymptomColors.goodSymptom.withValues(alpha: 0.5)
            : SymptomColors.symptomBase.withValues(alpha: 0.5))
        : (disabled
              ? AppColors.border.withValues(alpha: 0.5)
              : AppColors.border);
    
    final textColor = selected
        ? (isGood 
            ? const Color(0xFF2E7D32) // 초록색 배경에 어울리는 진한 초록색 텍스트
            : const Color(0xFF8E7CC3)) // 보라색 배경에 어울리는 진한 보라색 텍스트
        : (disabled
              ? AppColors.textSecondary.withValues(alpha: 0.5)
              : AppColors.textSecondary);

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
