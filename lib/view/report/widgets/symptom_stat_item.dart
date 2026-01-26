import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class SymptomStatItemData {
  final String label;
  final int count;
  final double ratio; // 0~1
  final Color color;
  final List<String>? fullSymptomNames; // 툴팁용 전체 증상 리스트

  const SymptomStatItemData({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
    this.fullSymptomNames,
  });
}

class SymptomStatItem extends StatelessWidget {
  final SymptomStatItemData data;

  const SymptomStatItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isExample = data.color == AppColors.textDisabled;
    final barBg = isExample
        ? AppColors.textDisabled.withValues(alpha: 0.2)
        : AppColors.primaryLight.withValues(alpha: 0.5);
    final barWidthRatio = data.ratio.clamp(0, 1).toDouble();

    final hasManySymptoms = (data.fullSymptomNames?.length ?? 0) > 3;
    final tooltipMessage = data.fullSymptomNames?.join(', ');

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.label,
                style: AppTextStyles.body.copyWith(
                  fontSize: AppTextStyles.body.fontSize,
                  color: isExample
                      ? AppColors.textDisabled
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isExample
                    ? AppColors.textDisabled.withValues(alpha: 0.2)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '${data.count}회',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: isExample
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barWidthRatio,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: data.color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );

    if (!isExample && hasManySymptoms && tooltipMessage != null) {
      return Tooltip(
        message: tooltipMessage,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: false,
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTextStyles.caption.copyWith(color: Colors.white),
        child: content,
      );
    }

    return content;
  }
}
