import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';

class DayCell extends StatelessWidget {
  final DateTime date;
  final bool isOutsideMonth;
  final VoidCallback onTap;
  final bool isPeriod;
  final bool isFertile;
  final bool isOvulation;
  final bool isExpectedPeriod;
  final bool isExpectedFertile;
  final bool isExpectedPeriodStart;
  final bool isToday;
  final bool isSelected;
  final bool hasRecord;
  final bool isPeriodStart;
  final bool isPeriodEnd;
  final bool isFertileStart;
  final DateTime? today;

  const DayCell({
    super.key,
    required this.date,
    required this.isOutsideMonth,
    required this.onTap,
    required this.isPeriod,
    required this.isFertile,
    required this.isOvulation,
    required this.isExpectedPeriod,
    required this.isExpectedFertile,
    required this.isExpectedPeriodStart,
    required this.isToday,
    required this.isSelected,
    required this.hasRecord,
    required this.isPeriodStart,
    required this.isPeriodEnd,
    required this.isFertileStart,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final showPeriod = !isOutsideMonth && isPeriod;
    final showFertile = !isOutsideMonth && isFertile;
    final showExpectedPeriod = !isOutsideMonth && isExpectedPeriod;
    final showExpectedFertile = !isOutsideMonth && isExpectedFertile;
    final showOvulation = !isOutsideMonth && isOvulation;
    final showRecord = !isOutsideMonth && hasRecord;
    final showSelected = !isOutsideMonth && isSelected;

    Color? bgColor;

    // 오늘 이후 날짜인지 확인
    final isFutureDate =
        today != null &&
        !isOutsideMonth &&
        DateTime(
          date.year,
          date.month,
          date.day,
        ).isAfter(DateTime(today!.year, today!.month, today!.day));

    Color textColor = isOutsideMonth
        ? AppColors.textDisabled.withValues(alpha: 0.5)
        : isFutureDate
        ? AppColors.textPrimary.withValues(alpha: 0.5)
        : AppColors.textPrimary;
    Color? borderColor;

    if (showPeriod) {
      bgColor = AppColors.primaryLight;
      textColor = AppColors.textPrimary;
    } else if (showFertile) {
      bgColor = const Color(0xFFE8F5F6);
    } else if (showExpectedPeriod) {
      bgColor = AppColors.primaryLight.withValues(alpha: 0.3);
    } else if (showExpectedFertile) {
      bgColor = const Color(0xFFE8F5F6).withValues(alpha: 0.3);
    }
    if (showSelected) {
      // 오늘 이후 날짜는 회색 테두리, 그 외는 기본 primary 색상
      borderColor = isFutureDate ? AppColors.textDisabled : AppColors.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: showSelected ? borderColor! : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  height: 18,
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: isToday ? 15 : 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w300,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                isOutsideMonth
                    ? const SizedBox.shrink()
                    : _buildMiddleIndicator(
                        isPeriod: showPeriod,
                        isPeriodStart: isPeriodStart,
                        isPeriodEnd: isPeriodEnd,
                        isFertile: showFertile,
                        isOvulation: showOvulation,
                        isFertileStart: isFertileStart,
                        isExpectedPeriod: showExpectedPeriod,
                        isExpectedPeriodStart: isExpectedPeriodStart,
                      ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: SizedBox(
                    height: 5,
                    width: 5,
                    child: showRecord
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleIndicator({
    required bool isPeriod,
    required bool isPeriodStart,
    required bool isPeriodEnd,
    required bool isFertile,
    required bool isOvulation,
    required bool isFertileStart,
    required bool isExpectedPeriod,
    required bool isExpectedPeriodStart,
  }) {
    Widget? indicator;
    // 시작일과 종료일이 같은 경우 '시작/종료'로 표시
    if (isPeriod && isPeriodStart && isPeriodEnd) {
      indicator = const Text(
        '시작/종료',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
        overflow: TextOverflow.visible,
      );
    } else if (isPeriod && isPeriodStart) {
      indicator = const Text(
        '시작',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
        overflow: TextOverflow.visible,
      );
    } else if (isPeriod && isPeriodEnd) {
      indicator = const Text(
        '종료',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
        overflow: TextOverflow.visible,
      );
    } else if (isOvulation) {
      indicator = const Text(
        '배란일',
        style: TextStyle(fontSize: 10, color: Color(0xFF2CA9D2)),
        overflow: TextOverflow.visible,
      );
    } else if (isExpectedPeriod && isExpectedPeriodStart) {
      indicator = const Text(
        '생리 예정',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
        overflow: TextOverflow.visible,
      );
    } else if (isFertile && !isOvulation && isFertileStart) {
      indicator = const Text(
        '가임기',
        style: TextStyle(fontSize: 10, color: Color(0xFF2CA9D2)),
        overflow: TextOverflow.visible,
      );
    }

    return SizedBox(
      height: 14,
      child: indicator == null
          ? const SizedBox.shrink()
          : OverflowBox(
              minHeight: 14,
              maxHeight: 16,
              child: Center(child: indicator),
            ),
    );
  }
}
