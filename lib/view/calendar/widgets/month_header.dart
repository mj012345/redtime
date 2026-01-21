import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<DateTime>? onMonthSelected; // 월 선택 콜백

  const MonthHeader({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    this.onMonthSelected,
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
          GestureDetector(
            onTap: onMonthSelected != null
                ? () => _showMonthPicker(
                    context,
                    month,
                    DateTime.now(),
                    onMonthSelected!,
                  )
                : null,
            child: Text(
              label,
              style: AppTextStyles.title.copyWith(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
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
                borderRadius: BorderRadius.circular(10),
                color: AppColors.textDisabled.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  '오늘',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.9),
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

  /// 월 선택 다이얼로그 표시
  void _showMonthPicker(
    BuildContext context,
    DateTime currentMonth,
    DateTime today,
    ValueChanged<DateTime> onMonthSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => _MonthPickerDialog(
        currentMonth: currentMonth,
        today: today,
        onMonthSelected: onMonthSelected,
      ),
    );
  }
}

/// 월 선택 다이얼로그
class _MonthPickerDialog extends StatefulWidget {
  final DateTime currentMonth;
  final DateTime today;
  final ValueChanged<DateTime> onMonthSelected;

  const _MonthPickerDialog({
    required this.currentMonth,
    required this.today,
    required this.onMonthSelected,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.currentMonth.year;
    selectedMonth = widget.currentMonth.month;
  }

  /// 해당 월이 현재 달 이후인지 확인
  bool _isFutureMonth(int year, int month) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    if (year > currentYear) return true;
    if (year == currentYear && month > currentMonth) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 연도 선택 및 오늘 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 연도 선택 (왼쪽)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          selectedYear--;
                        });
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$selectedYear년',
                      style: AppTextStyles.title.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          selectedYear++;
                        });
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                // 오늘 버튼 (오른쪽)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedYear = widget.today.year;
                      selectedMonth = widget.today.month;
                    });
                    widget.onMonthSelected(
                      DateTime(widget.today.year, widget.today.month),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textDisabled.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'TODAY',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textDisabled,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 월 선택 그리드
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = month == widget.currentMonth.month && selectedYear == widget.currentMonth.year;
                final isFuture = _isFutureMonth(selectedYear, month);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedMonth = month;
                    });
                    widget.onMonthSelected(
                      DateTime(selectedYear, selectedMonth),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$month월',
                        style: AppTextStyles.body.copyWith(
                          color: isSelected
                              ? Colors.white
                              : isFuture
                              ? AppColors.textPrimary.withValues(alpha: 0.5)
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
