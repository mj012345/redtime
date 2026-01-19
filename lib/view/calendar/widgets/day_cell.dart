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
  final int symptomCount; // 증상 개수 (0이면 표시 안 함)
  final bool hasMemo; // 메모 여부
  final bool hasRelationship; // 관계(하트) 여부
  final bool isPeriodStart;
  final bool isPeriodEnd;
  final bool isFertileStart;
  final bool isFertileEnd;
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
    this.symptomCount = 0,
    this.hasMemo = false,
    this.hasRelationship = false,
    required this.isPeriodStart,
    required this.isPeriodEnd,
    required this.isFertileStart,
    required this.isFertileEnd,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final showPeriod = !isOutsideMonth && isPeriod;
    final showFertile = !isOutsideMonth && isFertile;
    final showExpectedPeriod = !isOutsideMonth && isExpectedPeriod;
    final showExpectedFertile = !isOutsideMonth && isExpectedFertile;
    final showOvulation = !isOutsideMonth && isOvulation;
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
      bgColor = SymptomColors.period;
      textColor = AppColors.textPrimary;
    } else if (showFertile) {
      bgColor = SymptomColors.fertile;
    } else if (showExpectedPeriod) {
      bgColor = SymptomColors.period.withValues(alpha: 0.3);
    } else if (showExpectedFertile) {
      bgColor = SymptomColors.fertile.withValues(alpha: 0.3);
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
              borderRadius: BorderRadius.only(
                topLeft: (showPeriod && isPeriodStart) || (showFertile && isFertileStart)
                    ? const Radius.circular(8)
                    : Radius.zero,
                bottomLeft: (showPeriod && isPeriodStart) || (showFertile && isFertileStart)
                    ? const Radius.circular(8)
                    : Radius.zero,
                topRight: (showPeriod && isPeriodEnd) || (showFertile && isFertileEnd)
                    ? const Radius.circular(8)
                    : Radius.zero,
                bottomRight: (showPeriod && isPeriodEnd) || (showFertile && isFertileEnd)
                    ? const Radius.circular(8)
                    : Radius.zero,
              ),
              border: showSelected
                  ? Border.all(
                      color: borderColor!,
                      width: 1,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 3,
                right: 3,
                top: 0,
              ),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 1),
                  // 1. 날짜 (고정 위치)
                  SizedBox(
                    height: 14,
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: isToday ? 12 : 11,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w300,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 2. 텍스트 표시 (고정 높이 영역)
                  SizedBox(
                    height: 12,
                    child: isOutsideMonth
                        ? const SizedBox.shrink()
                        : Center(
                            child: _buildMiddleIndicator(
                              isPeriod: showPeriod,
                              isPeriodStart: isPeriodStart,
                              isPeriodEnd: isPeriodEnd,
                              isFertile: showFertile,
                              isOvulation: showOvulation,
                              isFertileStart: isFertileStart,
                              isExpectedPeriod: showExpectedPeriod,
                              isExpectedPeriodStart: isExpectedPeriodStart,
                            ),
                          ),
                  ),
                  // 3. 아이콘 (고정 높이 영역)
                  SizedBox(
                    height: 12,
                    child: isOutsideMonth
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 하트 아이콘 (관계)
                              if (hasRelationship) ...[
                                const Icon(
                                  Icons.favorite,
                                  size: 8,
                                  color: SymptomColors.relationship,
                                ),
                                if (hasRecord || hasMemo) const SizedBox(width: 1),
                              ],
                              // 증상 아이콘
                              if (hasRecord) ...[
                                const Icon(
                                  Icons.add_circle,
                                  size: 8,
                                  color: SymptomColors.symptomBase,
                                ),
                                if (hasMemo) const SizedBox(width: 1),
                              ],
                              // 메모 아이콘
                              if (hasMemo)
                                const Icon(
                                  Icons.assignment,
                                  size: 8,
                                  color: AppColors.textSecondary,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
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
        style: TextStyle(fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isPeriod && isPeriodStart) {
      indicator = const Text(
        '시작',
        style: TextStyle(fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isPeriod && isPeriodEnd) {
      indicator = const Text(
        '종료',
        style: TextStyle(fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isOvulation) {
      indicator = const Text(
        '배란일',
        style: TextStyle(fontSize: 8, color: Color(0xFF55B292), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isExpectedPeriod && isExpectedPeriodStart) {
      indicator = const Text(
        '생리예정',
        style: TextStyle(fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isFertile && !isOvulation && isFertileStart) {
      indicator = const Text(
        '가임기',
        style: TextStyle(fontSize: 8, color: Color(0xFF55B292), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    }

    if (indicator == null) {
      return const SizedBox.shrink();
    }
    return indicator;
  }
}
