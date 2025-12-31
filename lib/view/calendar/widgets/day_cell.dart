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
    Color textColor = isOutsideMonth
        ? AppColors.textDisabled
        : AppColors.textPrimary;
    Color? borderColor;

    if (showPeriod) {
      bgColor = AppColors.primaryLight;
      textColor = AppColors.textPrimary;
    } else if (showFertile) {
      bgColor = const Color(0xFFE8F5F6);
    } else if (showExpectedPeriod) {
      bgColor = AppColors.primaryLight.withValues(alpha: 0.5);
    } else if (showExpectedFertile) {
      bgColor = const Color(0xFFE8F5F6).withValues(alpha: 0.5);
    }
    if (showSelected) {
      borderColor = AppColors.primary;
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
                const SizedBox(height: 1),
                SizedBox(
                  height: 25,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isToday)
                        Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.border,
                          ),
                        ),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: textColor,
                        ),
                      ),
                    ],
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
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SizedBox(
                    height: 6,
                    width: 6,
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
    if (isPeriod && isPeriodStart) {
      indicator = const Text(
        '시작',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
      );
    } else if (isPeriod && isPeriodEnd) {
      indicator = const Text(
        '종료',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
      );
    } else if (isOvulation) {
      indicator = const Text(
        '배란일',
        style: TextStyle(fontSize: 10, color: Color(0xFF2CA9D2)),
      );
    } else if (isExpectedPeriod && isExpectedPeriodStart) {
      indicator = const Text(
        '생리 예정',
        style: TextStyle(fontSize: 10, color: AppColors.primary),
      );
    } else if (isFertile && !isOvulation && isFertileStart) {
      indicator = const Text(
        '가임기',
        style: TextStyle(fontSize: 10, color: Color(0xFF2CA9D2)),
      );
    }

    return SizedBox(
      height: 14,
      child: indicator == null
          ? const SizedBox.shrink()
          : Center(child: indicator),
    );
  }
}
