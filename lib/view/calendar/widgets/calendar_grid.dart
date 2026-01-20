import 'package:flutter/material.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'day_cell.dart';

class CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final List<PeriodCycle> periodCycles;
  final List<DateTime> periodDays;
  final List<DateTime> fertileWindowDays;
  final DateTime? ovulationDay;
  final List<DateTime> ovulationDays;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> expectedFertileWindowDays;
  final DateTime? expectedOvulationDay;
  final bool Function(DateTime) hasRecordFor; // 증상 기록 여부 확인 함수
  final int Function(DateTime) getSymptomCount; // 증상 개수 반환 함수
  final bool Function(DateTime) hasMemoFor; // 메모 여부 확인 함수
  final bool Function(DateTime) hasRelationshipFor; // 관계 여부 확인 함수
  final ValueChanged<DateTime> onSelect;

  const CalendarGrid({
    super.key,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.periodCycles,
    required this.periodDays,
    required this.fertileWindowDays,
    required this.ovulationDay,
    required this.ovulationDays,
    required this.expectedPeriodDays,
    required this.expectedFertileWindowDays,
    required this.expectedOvulationDay,
    required this.hasRecordFor,
    required this.getSymptomCount,
    required this.hasMemoFor,
    required this.hasRelationshipFor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final firstDay = DateTime(month.year, month.month, 1);
    final startWeekday = firstDay.weekday;
    final startOffset = startWeekday % 7;
    // 항상 6주(42일)로 고정
    const totalCells = 42;
    final startDate = firstDay.subtract(Duration(days: startOffset));

    final rows = <List<DateTime>>[];
    for (int idx = 0; idx < totalCells; idx += 7) {
      final week = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        final day = startDate.add(Duration(days: idx + d));
        week.add(DateTime(day.year, day.month, day.day));
      }
      rows.add(week);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekdays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12,
                        color: (w == '일' || w == '토')
                            ? AppColors.primary
                            : AppColors.textPrimary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows) ...[
              SizedBox(
                height: 45,
                child: Row(
                  children: row
                      .map(
                        (day) => Expanded(
                          child: DayCell(
                            date: day,
                            isOutsideMonth: day.month != month.month,
                            onTap: day.month != month.month ? () {} : () => onSelect(day),
                            isPeriod: _containsDate(periodDays, day),
                            isFertile: _containsDate(fertileWindowDays, day),
                            isOvulation: _containsDate([
                              if (ovulationDay != null) ovulationDay!,
                              ...ovulationDays,
                            ], day),
                            isExpectedPeriod: _containsDate(
                              expectedPeriodDays,
                              day,
                            ),
                            isExpectedFertile: _containsDate(
                              expectedFertileWindowDays,
                              day,
                            ),
                            isExpectedPeriodStart: _isExpectedPeriodStart(
                              expectedPeriodDays,
                              day,
                            ),
                            isToday: _sameDay(day, today),
                            isSelected:
                                selectedDay != null &&
                                _sameDay(day, selectedDay!),
                            hasRecord: hasRecordFor(day),
                            symptomCount: getSymptomCount(day),
                            hasMemo: hasMemoFor(day),
                            hasRelationship: hasRelationshipFor(day),
                            isPeriodStart: _isRangeStart(periodCycles, day),
                            isPeriodEnd: _isRangeEnd(periodCycles, day),
                            isFertileStart: _isFertileWindowStart(
                              fertileWindowDays,
                              day,
                            ),
                            isFertileEnd: _isFertileWindowEnd(
                              fertileWindowDays,
                              day,
                            ),
                            today: today,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _containsDate(List<DateTime> list, DateTime target) =>
    list.any((d) => _sameDay(d, target));

bool _isRangeStart(List<PeriodCycle> cycles, DateTime target) {
  for (final c in cycles) {
    if (c.contains(target)) {
      final start = DateTime(c.start.year, c.start.month, c.start.day);
      return _sameDay(start, target);
    }
  }
  return false;
}

bool _isRangeEnd(List<PeriodCycle> cycles, DateTime target) {
  for (final c in cycles) {
    if (c.contains(target)) {
      final end = c.end ?? c.start;
      final realEnd = end.isBefore(c.start) ? c.start : end;
      return _sameDay(realEnd, target);
    }
  }
  return false;
}

bool _isFertileWindowStart(List<DateTime> fertileWindowDays, DateTime target) {
  if (!_containsDate(fertileWindowDays, target)) return false;
  final sorted = [...fertileWindowDays]..sort((a, b) => a.compareTo(b));
  for (int i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    if (_sameDay(current, target)) {
      if (i == 0) return true;
      final prev = sorted[i - 1];
      final diff = current.difference(prev).inDays;
      if (diff > 1) return true;
      return false;
    }
  }
  return false;
}

bool _isFertileWindowEnd(List<DateTime> fertileWindowDays, DateTime target) {
  if (!_containsDate(fertileWindowDays, target)) return false;
  final sorted = [...fertileWindowDays]..sort((a, b) => a.compareTo(b));
  for (int i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    if (_sameDay(current, target)) {
      if (i == sorted.length - 1) return true;
      final next = sorted[i + 1];
      final diff = next.difference(current).inDays;
      if (diff > 1) return true;
      return false;
    }
  }
  return false;
}

bool _isExpectedPeriodStart(
  List<DateTime> expectedPeriodDays,
  DateTime target,
) {
  if (!_containsDate(expectedPeriodDays, target)) return false;
  final sorted = [...expectedPeriodDays]..sort((a, b) => a.compareTo(b));
  for (int i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    if (_sameDay(current, target)) {
      if (i == 0) return true;
      final prev = sorted[i - 1];
      if (current.difference(prev).inDays > 1) return true;
      return false;
    }
  }
  return false;
}
