import 'package:flutter/material.dart' hide Badge;
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'toggle_chip.dart';

class TodayCard extends StatelessWidget {
  final DateTime? selectedDay;
  final DateTime today;
  final List<PeriodCycle> periodCycles;
  final List<DateTime> periodDays;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> fertileWindowDays;
  final List<DateTime> expectedFertileWindowDays;
  final VoidCallback onPeriodStart;
  final VoidCallback onPeriodEnd;
  final bool isStartSelected;
  final bool isEndSelected;

  const TodayCard({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.periodCycles,
    required this.periodDays,
    required this.expectedPeriodDays,
    required this.fertileWindowDays,
    required this.expectedFertileWindowDays,
    required this.onPeriodStart,
    required this.onPeriodEnd,
    required this.isStartSelected,
    required this.isEndSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${selectedDay!.month}월 ${selectedDay!.day}일 ${_weekdayLabel(selectedDay!)}요일',
            style: AppTextStyles.title.copyWith(
              fontSize: 20,
              color: AppColors.primary,
            ),
          ),
              const SizedBox(width: AppSpacing.sm),
          Builder(
            builder: (context) {
                  final probability = _calculatePregnancyProbability(
                    selectedDay,
                  );

                  if (probability == null) {
                return const SizedBox.shrink();
              }

                  Color circleColor;
                  String text;

                switch (probability) {
                  case '낮음':
                    circleColor = const Color(0xFFC5C5C5);
                    text = '임신 확률 낮음';
                    break;
                  case '높음':
                    circleColor = const Color(0xFFA7C4A0);
                    text = '임신 확률 높음';
                    break;
                  default:
                    circleColor = const Color(0xFFFFD966);
                    text = '임신 확률 보통';
              }

              return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                  );
                },
                    ),
                ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ToggleChip(
                  icon: Icons.invert_colors,
                  label: '생리 시작',
                  selected: isStartSelected,
                  onTap: onPeriodStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ToggleChip(
                  icon: Icons.block,
                  label: '생리 종료',
                  selected: isEndSelected,
                  onTap: onPeriodEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(DateTime d) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return labels[d.weekday % 7];
  }

  String? _calculatePregnancyProbability(DateTime? day) {
    if (day == null) return null;

    if (periodCycles.isEmpty && expectedPeriodDays.isEmpty) {
      return null;
    }

    final threeMonthsLater = today.add(const Duration(days: 90));
    if (day.isAfter(threeMonthsLater)) {
      return null;
    }

    final allPeriodStarts = <DateTime>[];
    for (final cycle in periodCycles) {
      allPeriodStarts.add(cycle.start);
    }
    if (expectedPeriodDays.isNotEmpty) {
      DateTime? lastDate;
      for (final date in expectedPeriodDays) {
        if (lastDate == null || date.difference(lastDate).inDays > 1) {
          allPeriodStarts.add(date);
        }
        lastDate = date;
      }
    }

    for (final start in allPeriodStarts) {
      final diff = day.difference(start).inDays;
      if (diff >= -7 && diff <= 7) {
        return '낮음';
      }
    }

    final allFertileDays = [...fertileWindowDays, ...expectedFertileWindowDays];
    for (final fertileDay in allFertileDays) {
      if (_sameDay(fertileDay, day)) {
        return '높음';
      }
    }

    return '보통';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
