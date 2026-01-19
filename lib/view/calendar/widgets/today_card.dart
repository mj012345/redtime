import 'dart:math' as math;
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_svg/flutter_svg.dart';
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
  final bool hasMemo;
  final bool hasRelationship;
  final VoidCallback onMemoTap;
  final VoidCallback onRelationshipTap;

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
    required this.onMemoTap,
    required this.onRelationshipTap,
    this.hasMemo = false,
    this.hasRelationship = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedDay!.month}월 ${selectedDay!.day}일 ${_weekdayLabel(selectedDay!)}요일',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
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
                          circleColor = const Color(0xFF28965B);
                          text = '임신 확률 높음';
                          break;
                        default:
                          circleColor = const Color(0xFFBFBF67);
                          text = '임신 확률 보통';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: circleColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Transform.rotate(
                                  angle: 45 * math.pi / 180,
                                  child: SvgPicture.string(
                                    '''
                        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M10 12C10 14.2091 8.20914 16 6 16C3.79086 16 2 14.2091 2 12C2 9.79086 3.79086 8 6 8C8.20914 8 10 9.79086 10 12Z" fill="white"/>
                          <path d="M10 12C13 12 14 10 17 10C20 10 21 12 22 12" stroke="white" stroke-width="2" stroke-linecap="round"/>
                        </svg>
                        ''',
                                    width: 8,
                                    height: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              text,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onRelationshipTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      hasRelationship ? Icons.favorite : Icons.favorite_border,
                      size: 26,
                      color: hasRelationship
                          ? SymptomColors.relationship
                          : AppColors.textDisabled.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onMemoTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      hasMemo ? Icons.assignment : Icons.assignment_outlined,
                      size: 26,
                      color: hasMemo
                          ? AppColors.textSecondary
                          : AppColors.textDisabled.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: ToggleChip(
                icon: Icons.water_drop,
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
