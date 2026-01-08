import 'package:flutter/material.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'day_cell.dart';
import 'horizontal_line.dart';

/// 선택된 날짜가 포함된 주를 표시하는 위젯
class WeekRow extends StatelessWidget {
  final List<DateTime> week;
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
  final List<DateTime> symptomRecordDays;
  final ValueChanged<DateTime> onSelect;

  const WeekRow({
    super.key,
    required this.week,
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
    required this.symptomRecordDays,
    required this.onSelect,
  });

  bool _containsDate(List<DateTime> list, DateTime date) {
    return list.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HorizontalLine(),
        SizedBox(
          height: 50,
          child: Row(
            children: week
                .map(
                  (day) => Expanded(
                    child: DayCell(
                      date: day,
                      isOutsideMonth: false,
                      onTap: () => onSelect(day),
                      isPeriod: _containsDate(periodDays, day),
                      isFertile: _containsDate(fertileWindowDays, day),
                      isOvulation: _containsDate([
                        if (ovulationDay != null) ovulationDay!,
                        ...ovulationDays,
                      ], day),
                      isExpectedPeriod: _containsDate(expectedPeriodDays, day),
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
                          selectedDay != null && _sameDay(day, selectedDay!),
                      hasRecord: _containsDate(symptomRecordDays, day),
                      isPeriodStart: _isRangeStart(periodCycles, day),
                      isPeriodEnd: _isRangeEnd(periodCycles, day),
                      isFertileStart: _isFertileWindowStart(
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
    );
  }

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

  bool _isFertileWindowStart(
    List<DateTime> fertileWindowDays,
    DateTime target,
  ) {
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
}
