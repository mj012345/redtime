import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const MonthHeader({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final label = '${month.year}. ${month.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.title.copyWith(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onToday,
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textDisabled),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  'TODAY',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textDisabled,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
