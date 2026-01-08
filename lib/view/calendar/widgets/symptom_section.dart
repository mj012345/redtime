import 'package:flutter/material.dart';
import 'package:red_time_app/models/symptom_category.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'symptom_chip.dart';

class SymptomSection extends StatelessWidget {
  final List<SymptomCategory> categories;
  final Set<String> selectedLabels;
  final ValueChanged<String> onToggle;
  final VoidCallback? onMemoTap;
  final bool hasMemo;

  const SymptomSection({
    super.key,
    required this.categories,
    required this.selectedLabels,
    required this.onToggle,
    this.onMemoTap,
    this.hasMemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < categories.length; i++) ...[
          _Category(
            title: categories[i].title,
            groups: categories[i].groups,
            selectedLabels: selectedLabels,
            onToggle: onToggle,
            onMemoTap: onMemoTap,
            hasMemo: hasMemo,
          ),
          if (i != categories.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Category extends StatelessWidget {
  final String title;
  final List<List<String>> groups;
  final Set<String> selectedLabels;
  final ValueChanged<String> onToggle;
  final VoidCallback? onMemoTap;
  final bool hasMemo;

  const _Category({
    required this.title,
    required this.groups,
    required this.selectedLabels,
    required this.onToggle,
    this.onMemoTap,
    this.hasMemo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in groups) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: row
                .map(
                  (label) => SymptomChip(
                    label: label,
                    selected: label == '메모'
                        ? hasMemo
                        : selectedLabels.contains(label),
                    onTap: () => onToggle(label),
                    onMemoTap: label == '메모' ? onMemoTap : null,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
