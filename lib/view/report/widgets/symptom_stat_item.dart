import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class SymptomStatItemData {
  final String label;
  final int count;
  final double ratio; // 0~1
  final Color color;

  const SymptomStatItemData({
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });
}

class SymptomStatItem extends StatelessWidget {
  final SymptomStatItemData data;

  const SymptomStatItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final barBg = AppColors.primaryLight.withValues(alpha: 0.5);
    final barWidthRatio = data.ratio.clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              data.label,
              style: AppTextStyles.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '${data.count}회',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: data.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: barBg,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barWidthRatio,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: data.color,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
