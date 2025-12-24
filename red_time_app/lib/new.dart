import 'package:flutter/material.dart';

/// Figma 레이아웃(채널 8usim5es)을 단일 화면으로 구현한 예시입니다.
class FigmaCalendarPage extends StatefulWidget {
  const FigmaCalendarPage({super.key});

  @override
  State<FigmaCalendarPage> createState() => _FigmaCalendarPageState();
}

// ============================================================================
// [데이터 모델] 생리 주기를 관리하는 클래스
// ============================================================================
class _PeriodCycle {
  DateTime start;
  DateTime? end;
  _PeriodCycle(this.start, this.end);

  List<DateTime> toDays() {
    final s = DateTime(start.year, start.month, start.day);
    final e = end ?? s;
    final realEnd = e.isBefore(s) ? s : e;
    final days = <DateTime>[];
    var cur = s;
    while (!cur.isAfter(realEnd)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  bool contains(DateTime d) {
    final s = DateTime(start.year, start.month, start.day);
    final e = end ?? s;
    final realEnd = e.isBefore(s) ? s : e;
    return !d.isBefore(s) && !d.isAfter(realEnd);
  }
}

// ============================================================================
// [메인 상태 관리 클래스] 캘린더 화면의 상태와 로직을 관리
// ============================================================================
class _FigmaCalendarPageState extends State<FigmaCalendarPage> {
  // --------------------[상태 변수: 총 8가지 날짜 타입 관리]--------------------
  // today: 오늘 날짜
  final DateTime today = DateTime.now();

  // selectedDay: 달력에서 선택한 날짜
  DateTime? selectedDay = DateTime.now();

  // currentMonth: 현재 표시 중인 달
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // 실제 생리일 기록 (여러 주기 지원)
  List<DateTime> periodDays = [];
  List<_PeriodCycle> periodCycles = [];
  int? activeCycleIndex;

  // 실제 가임기/배란일 (계산값)
  List<DateTime> fertileWindowDays = [];
  DateTime? ovulationDay;

  // 예상 생리일 (계산값)
  List<DateTime> expectedPeriodDays = [];

  // 예상 가임기 (계산값)
  List<DateTime> expectedFertileWindowDays = [];

  // 예상 배란일 (계산값)
  DateTime? expectedOvulationDay;

  // 증상 기록이 있는 날짜 (예시: 11/11, 11/28)
  final List<DateTime> symptomRecordDays = [
    DateTime(2025, 11, 11),
    DateTime(2025, 11, 28),
  ];

  @override
  void initState() {
    super.initState();
    // 초기값: 오늘 날짜를 선택 상태로 설정
    selectedDay = today;
  }

  // =======================[생리 주기 관리 메서드] 생리 시작일 설정/해제=================================
  void _setPeriodStart() {
    if (selectedDay == null) return;
    final sd = DateTime(
      selectedDay!.year,
      selectedDay!.month,
      selectedDay!.day,
    );

    // 토글: 선택한 날짜가 어떤 주기의 시작일이면 한 번에 해제
    int? existingIdx = _findCycleIndexContaining(sd);
    if (existingIdx != null && _sameDay(periodCycles[existingIdx].start, sd)) {
      periodCycles.removeAt(existingIdx);
      if (activeCycleIndex != null && activeCycleIndex == existingIdx) {
        activeCycleIndex = null;
      } else if (activeCycleIndex != null && activeCycleIndex! > existingIdx) {
        activeCycleIndex = activeCycleIndex! - 1; // shift after removal
      }
      _recomputePeriodDays();
      return;
    }

    // 같은 날짜를 다시 누르면 해당 활성 주기 해제
    if (activeCycleIndex != null &&
        _sameDay(periodCycles[activeCycleIndex!].start, sd)) {
      periodCycles.removeAt(activeCycleIndex!);
      activeCycleIndex = null;
      _recomputePeriodDays();
      return;
    }

    // 기존 주기 안이거나 시작일 전날이면 그 주기 조정
    final idx = _findCycleIndexContainingOrPrev(sd);
    if (idx != null) {
      final cycle = periodCycles[idx];
      cycle.start = sd;
      if (cycle.end != null && cycle.end!.isBefore(cycle.start)) {
        cycle.end = cycle.start;
      }
      activeCycleIndex = idx;
      _recomputePeriodDays();
      return;
    }

    // 새 주기 추가
    periodCycles.add(_PeriodCycle(sd, null));
    activeCycleIndex = periodCycles.length - 1;
    _recomputePeriodDays();
  }

  // =======================[생리 주기 관리 메서드] 생리 종료일 설정/해제=================================
  void _setPeriodEnd() {
    if (selectedDay == null) return;
    final sd = DateTime(
      selectedDay!.year,
      selectedDay!.month,
      selectedDay!.day,
    );

    // 활성 주기 선택 또는 포함된 주기 찾기
    int? idx = activeCycleIndex;
    idx ??= _findCycleIndexContaining(sd);

    // 없으면 새 주기 생성 (start = sd, end = sd)
    if (idx == null) {
      periodCycles.add(_PeriodCycle(sd, sd));
      activeCycleIndex = periodCycles.length - 1;
      _recomputePeriodDays();
      return;
    }

    final cycle = periodCycles[idx];
    if (sd.isBefore(cycle.start)) {
      // 종료일이 시작일보다 앞이면 시작일을 종료일로 이동
      cycle.start = sd;
      cycle.end = sd;
    } else {
      cycle.end = sd;
    }
    activeCycleIndex = idx;
    _recomputePeriodDays();
  }

  // =======================[데이터 재계산 메서드] 생리 주기 변경 시 periodDays 재계산=================================
  void _recomputePeriodDays() {
    final set = <DateTime>{};
    for (final c in periodCycles) {
      set.addAll(c.toDays());
    }
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    periodDays = list;
    _recomputeDerivedFertility();
    setState(() {});
  }

  // ========================================================================
  // [데이터 재계산 메서드] 가임기/배란일/예상값 계산
  // - 최근 4개 주기 간격 평균으로 주기 길이 계산
  // - 각 생리 주기마다 배란일과 가임기 계산
  // - 3개월치 예상 생리일, 가임기, 배란일 계산
  // ========================================================================
  void _recomputeDerivedFertility() {
    if (periodCycles.isEmpty) {
      fertileWindowDays = [];
      ovulationDay = null;
      expectedPeriodDays = [];
      expectedFertileWindowDays = [];
      expectedOvulationDay = null;
      return;
    }

    // 최근 주기 간격 평균 (최대 최근 4개), 없으면 기본 28일
    final sorted = [...periodCycles]
      ..sort((a, b) => a.start.compareTo(b.start));
    final intervals = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].start.difference(sorted[i - 1].start).inDays;
      if (diff > 0) intervals.add(diff);
    }

    int cycleLength;
    if (intervals.length >= 2) {
      final recent = intervals.sublist(
        intervals.length >= 4 ? intervals.length - 4 : 0,
      );
      cycleLength = recent.reduce((a, b) => a + b) ~/ recent.length;
    } else {
      cycleLength = 28;
    }

    // 모든 생리 주기에 대해 가임기와 배란일 계산
    fertileWindowDays = [];
    ovulationDay = null; // 가장 최근 배란일만 유지 (UI 호환성)

    const luteal = 14;
    final targetDay = cycleLength - luteal;

    // 각 생리 주기마다 배란일과 가임기 계산
    for (final cycle in sorted) {
      // 배란일: 각 주기 시작 + (cycleLength - 14)
      final cycleOvulation = cycle.start.add(Duration(days: targetDay));
      if (ovulationDay == null || cycleOvulation.isAfter(ovulationDay!)) {
        ovulationDay = cycleOvulation; // 가장 최근 배란일 유지
      }

      // 가임기: 배란일 -5일 ~ 배란일 +2일 (총 8일)
      final startWindow = cycleOvulation.subtract(const Duration(days: 5));
      for (int i = 0; i < 8; i++) {
        fertileWindowDays.add(
          DateTime(startWindow.year, startWindow.month, startWindow.day + i),
        );
      }
    }

    // 중복 제거 및 정렬
    fertileWindowDays = fertileWindowDays.toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    // 예상값 계산을 위한 현재 주기 정보
    final currentCycle = sorted.last;
    final periodDuration = currentCycle.end != null
        ? currentCycle.end!.difference(currentCycle.start).inDays + 1
        : 1;

    // 예상 생리일, 배란일, 가임기: 3개월치 계산
    expectedPeriodDays = [];
    expectedFertileWindowDays = [];
    expectedOvulationDay = null; // 첫 번째 예상 배란일만 유지 (UI 호환성)

    DateTime nextPeriodStart = currentCycle.start.add(
      Duration(days: cycleLength),
    );

    // 3개월치 예상값 계산
    for (int month = 0; month < 3; month++) {
      // 예상 생리일 (4일간)
      for (int i = 0; i < periodDuration; i++) {
        expectedPeriodDays.add(
          DateTime(
            nextPeriodStart.year,
            nextPeriodStart.month,
            nextPeriodStart.day + i,
          ),
        );
      }

      // 예상 배란일
      final expectedOvulation = nextPeriodStart.add(Duration(days: targetDay));
      if (month == 0) {
        expectedOvulationDay = expectedOvulation; // 첫 번째만 유지
      }

      // 예상 가임기: 배란일 -5일 ~ 배란일 +2일 (총 8일)
      final expectedStartWindow = expectedOvulation.subtract(
        const Duration(days: 5),
      );
      for (int i = 0; i < 8; i++) {
        expectedFertileWindowDays.add(
          DateTime(
            expectedStartWindow.year,
            expectedStartWindow.month,
            expectedStartWindow.day + i,
          ),
        );
      }

      // 다음 예상 생리 시작일 계산 (현재 예상 생리 시작일 + cycleLength)
      nextPeriodStart = nextPeriodStart.add(Duration(days: cycleLength));
    }
  }

  // ===================[유틸리티 메서드] 생리 주기 인덱스 찾기 (포함되거나 전날)========================
  int? _findCycleIndexContainingOrPrev(DateTime d) {
    for (int i = 0; i < periodCycles.length; i++) {
      final c = periodCycles[i];
      if (c.contains(d)) return i;
      final prevDay = c.start.subtract(const Duration(days: 1));
      if (_sameDay(prevDay, d)) return i;
    }
    return null;
  }

  // =====================[유틸리티 메서드] 생리 주기 인덱스 찾기 (날짜가 포함된 주기)=======================
  int? _findCycleIndexContaining(DateTime d) {
    for (int i = 0; i < periodCycles.length; i++) {
      if (periodCycles[i].contains(d)) return i;
    }
    return null;
  }

  bool _isSelectedDayStart() {
    if (selectedDay == null) return false;
    for (final c in periodCycles) {
      if (_sameDay(c.start, selectedDay!)) return true;
    }
    return false;
  }

  bool _isSelectedDayEnd() {
    if (selectedDay == null) return false;
    for (final c in periodCycles) {
      final end = c.end ?? c.start;
      final realEnd = end.isBefore(c.start) ? c.start : end;
      if (_sameDay(realEnd, selectedDay!)) return true;
    }
    return false;
  }

  // ==================[UI 빌드 메서드] 메인 화면 구성==================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      body: SafeArea(
        child: Container(
          color: const Color(0xFFFFFDFC),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _MonthHeader(
                month: currentMonth,
                onPrev: () {
                  setState(() {
                    currentMonth = DateTime(
                      currentMonth.year,
                      currentMonth.month - 1,
                    );
                  });
                },
                onNext: () {
                  setState(() {
                    currentMonth = DateTime(
                      currentMonth.year,
                      currentMonth.month + 1,
                    );
                  });
                },
                onToday: () {
                  setState(() {
                    selectedDay = today;
                    currentMonth = DateTime(today.year, today.month);
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 선택 상태 계산: 시작/종료는 동시에 선택되지 않도록 종료는 시작이 아닐 때만 표시
                        Builder(
                          builder: (context) {
                            final startSel = _isSelectedDayStart();
                            final endSel = !startSel && _isSelectedDayEnd();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Calendar(
                                  month: currentMonth,
                                  today: today,
                                  selectedDay: selectedDay,
                                  periodCycles: periodCycles,
                                  periodDays: periodDays,
                                  fertileWindowDays: fertileWindowDays,
                                  ovulationDay: ovulationDay,
                                  expectedPeriodDays: expectedPeriodDays,
                                  expectedFertileWindowDays:
                                      expectedFertileWindowDays,
                                  expectedOvulationDay: expectedOvulationDay,
                                  symptomRecordDays: symptomRecordDays,
                                  onSelect: (day) {
                                    setState(() {
                                      selectedDay = day;
                                    });
                                  },
                                ),
                                const SizedBox(height: 24),
                                _TodayCard(
                                  selectedDay: selectedDay,
                                  today: today,
                                  periodCycles: periodCycles,
                                  periodDays: periodDays,
                                  expectedPeriodDays: expectedPeriodDays,
                                  fertileWindowDays: fertileWindowDays,
                                  expectedFertileWindowDays:
                                      expectedFertileWindowDays,
                                  onPeriodStart: _setPeriodStart,
                                  onPeriodEnd: _setPeriodEnd,
                                  isStartSelected: startSel,
                                  isEndSelected: endSel,
                                ),
                                const SizedBox(height: 16),
                                const SizedBox(height: 24),
                                const _SymptomSection(),
                                const SizedBox(height: 24),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

// ============================================================================
// [위젯 클래스] 월 헤더 (이전/다음 월 이동 버튼)
// ============================================================================
class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthHeader({
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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD32F2F),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onToday,
            child: Container(
              width: 60,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF999999)),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  'TODAY',
                  style: const TextStyle(
                    color: Color(0xFF999999),
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

// ============================================================================
// [위젯 클래스] 캘린더 그리드 (요일 헤더 + 날짜 셀들)
// ============================================================================
class _Calendar extends StatelessWidget {
  final DateTime month;
  final DateTime today;
  final DateTime? selectedDay;
  final List<_PeriodCycle> periodCycles;
  final List<DateTime> periodDays;
  final List<DateTime> fertileWindowDays;
  final DateTime? ovulationDay;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> expectedFertileWindowDays;
  final DateTime? expectedOvulationDay;
  final List<DateTime> symptomRecordDays;
  final ValueChanged<DateTime> onSelect;

  const _Calendar({
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.periodCycles,
    required this.periodDays,
    required this.fertileWindowDays,
    required this.ovulationDay,
    required this.expectedPeriodDays,
    required this.expectedFertileWindowDays,
    required this.expectedOvulationDay,
    required this.symptomRecordDays,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // 요일 순서: 일요일 시작
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mon ... 7=Sun
    final startOffset = startWeekday % 7; // Sun -> 0, Mon ->1 ... Sat->6

    final cells = <DateTime?>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(null); // 앞쪽 빈 칸
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = <List<DateTime?>>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    return Column(
      children: [
        // 요일 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekdays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 13,
                        color: (w == '일' || w == '토')
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF555555),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 5),
        // 캘린더 그리드
        Column(
          children: [
            for (final row in rows) ...[
              _HorizontalLine(),
              SizedBox(
                height: 60,
                child: Row(
                  children: row
                      .map(
                        (day) => Expanded(
                          child: _DayCell(
                            day: day?.day,
                            onTap: day == null ? null : () => onSelect(day),
                            isPeriod:
                                day != null && _containsDate(periodDays, day),
                            isFertile:
                                day != null &&
                                _containsDate(fertileWindowDays, day),
                            isOvulation:
                                day != null &&
                                ovulationDay != null &&
                                _sameDay(day, ovulationDay!),
                            isExpectedPeriod:
                                day != null &&
                                _containsDate(expectedPeriodDays, day),
                            isExpectedFertile:
                                day != null &&
                                _containsDate(expectedFertileWindowDays, day),
                            isToday: day != null && _sameDay(day, today),
                            isSelected:
                                day != null &&
                                selectedDay != null &&
                                _sameDay(day, selectedDay!),
                            hasRecord:
                                day != null &&
                                _containsDate(symptomRecordDays, day),
                            isPeriodStart:
                                day != null && _isRangeStart(periodCycles, day),
                            isPeriodEnd:
                                day != null && _isRangeEnd(periodCycles, day),
                            isFertileStart:
                                day != null &&
                                _isFertileWindowStart(fertileWindowDays, day),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            _HorizontalLine(),
          ],
        ),
      ],
    );
  }
}

// ==================[유틸리티 함수] 날짜 비교 및 검색===============================
// 두 날짜가 같은 날인지 확인
bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// 리스트에 해당 날짜가 포함되어 있는지 확인
bool _containsDate(List<DateTime> list, DateTime target) {
  return list.any((d) => _sameDay(d, target));
}

// 생리 주기의 시작일인지 확인
bool _isRangeStart(List<_PeriodCycle> cycles, DateTime target) {
  for (final c in cycles) {
    if (c.contains(target)) {
      final start = DateTime(c.start.year, c.start.month, c.start.day);
      return _sameDay(start, target);
    }
  }
  return false;
}

// 생리 주기의 종료일인지 확인
bool _isRangeEnd(List<_PeriodCycle> cycles, DateTime target) {
  for (final c in cycles) {
    if (c.contains(target)) {
      final end = c.end ?? c.start;
      final realEnd = end.isBefore(c.start) ? c.start : end;
      return _sameDay(realEnd, target);
    }
  }
  return false;
}

// 가임기 구간의 첫 시작일에만 텍스트 표시)
bool _isFertileWindowStart(List<DateTime> fertileWindowDays, DateTime target) {
  if (!_containsDate(fertileWindowDays, target)) {
    return false;
  }

  // 정렬된 가임기 리스트에서 연속된 구간의 첫 시작일 찾기
  final sorted = [...fertileWindowDays]..sort((a, b) => a.compareTo(b));

  // 각 연속된 구간의 첫 번째 날짜 찾기
  for (int i = 0; i < sorted.length; i++) {
    final current = sorted[i];
    if (_sameDay(current, target)) {
      // 이전 날짜가 없거나, 이전 날짜가 연속되지 않으면 시작일
      if (i == 0) {
        return true;
      }
      final prev = sorted[i - 1];
      final diff = current.difference(prev).inDays;
      if (diff > 1) {
        return true;
      }
      return false;
    }
  }
  return false;
}

// ============================================================================
// [위젯 클래스] 달력 가로선
// ============================================================================
class _HorizontalLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFEEEEEE));
  }
}

// ============================================================================
// [위젯 클래스] 달력 날짜 셀 (개별 날짜 표시)
// - 생리일, 가임기, 배란일, 오늘, 선택 상태 등을 시각화
// - 오늘 날짜는 원형 배경으로 강조 표시
// ============================================================================
class _DayCell extends StatelessWidget {
  final int? day;
  final VoidCallback? onTap;
  final bool isPeriod;
  final bool isFertile;
  final bool isOvulation;
  final bool isExpectedPeriod;
  final bool isExpectedFertile;
  final bool isToday;
  final bool isSelected;
  final bool hasRecord;
  final bool isPeriodStart;
  final bool isPeriodEnd;
  final bool isFertileStart;

  const _DayCell({
    required this.day,
    required this.onTap,
    required this.isPeriod,
    required this.isFertile,
    required this.isOvulation,
    required this.isExpectedPeriod,
    required this.isExpectedFertile,
    required this.isToday,
    required this.isSelected,
    required this.hasRecord,
    required this.isPeriodStart,
    required this.isPeriodEnd,
    required this.isFertileStart,
  });

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    Color? bgColor;
    Color textColor = const Color(0xFF333333);
    Color? borderColor;

    if (isPeriod) {
      bgColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFF333333);
    } else if (isFertile) {
      bgColor = const Color(0xFFE8F5F6);
    } else if (isExpectedPeriod) {
      bgColor = const Color(0xFFFFEBEE).withValues(alpha: 0.5);
    } else if (isExpectedFertile) {
      bgColor = const Color(0xFFE8F5F6).withValues(alpha: 0.5);
    }

    if (isSelected) {
      borderColor = const Color(0xFFD32F2F);
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
              border: Border(
                top: isSelected
                    ? BorderSide(color: borderColor!, width: 1)
                    : BorderSide(color: Colors.transparent, width: 1),
                left: isSelected
                    ? BorderSide(color: borderColor!, width: 1)
                    : BorderSide(color: Colors.transparent, width: 1),
                right: isSelected
                    ? BorderSide(color: borderColor!, width: 1)
                    : BorderSide(color: Colors.transparent, width: 1),
                bottom: isSelected
                    ? BorderSide(color: borderColor!, width: 1)
                    : BorderSide(color: Colors.transparent, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 3), // 달력 가로선과 날짜 사이 간격
                SizedBox(
                  height: 25, // 오늘을 표시하는 원형 배경의 높이와 동일하게 고정
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 오늘 날짜일 때만 네모 아이콘 표시
                      if (isToday) ...[
                        // 오늘 내부 배경
                        Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            // borderRadius: BorderRadius.circular(100),
                            shape: BoxShape.circle,
                            color: const Color(0xFFEEEEEE),
                          ),
                        ),
                      ],
                      // 날짜 텍스트 (모든 날짜 동일한 위치)
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                // 중단: 배란/가임기 텍스트/아이콘
                _buildMiddleIndicator(textColor),
                const SizedBox(height: 2),
                // 하단: 아이콘 영역 (텍스트 아래 줄에 고정)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 증상 아이콘(노랑)만 표시, 없으면 자리 유지
                      if (hasRecord)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8D5656),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(width: 6, height: 6), // 자리 유지용
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 날짜 셀 중간 영역 표시기 (텍스트: 시작/종료/배란일/가임기)
  Widget _buildMiddleIndicator(Color textColor) {
    if (isPeriod && isPeriodStart) {
      return Text('시작', style: TextStyle(fontSize: 10, color: textColor));
    }

    if (isPeriod && isPeriodEnd) {
      return Text('종료', style: TextStyle(fontSize: 10, color: textColor));
    }

    if (isOvulation) {
      // 배란일 텍스트
      return Text(
        '배란일',
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (isFertile && !isOvulation && isFertileStart) {
      // 가임기 텍스트 (첫 시작일에만 표시)
      return Text(
        '가임기',
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    // 표시할 것이 없으면 빈 영역 유지
    return const SizedBox.shrink();
  }
}

// ============================================================================
// [위젯 클래스] 선택된 날짜 카드 (생리 시작/종료 버튼 포함)
// ============================================================================
class _TodayCard extends StatelessWidget {
  final DateTime? selectedDay;
  final DateTime today;
  final List<_PeriodCycle> periodCycles;
  final List<DateTime> periodDays;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> fertileWindowDays;
  final List<DateTime> expectedFertileWindowDays;
  final VoidCallback onPeriodStart;
  final VoidCallback onPeriodEnd;
  final bool isStartSelected;
  final bool isEndSelected;
  const _TodayCard({
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

  String _weekdayLabel(DateTime d) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return labels[d.weekday % 7];
  }

  // 임신 확률 계산: "낮음", "높음", "보통"
  String? _calculatePregnancyProbability(DateTime? day) {
    if (day == null) return null;

    // 생리 기록이 없어서 예측 불가능한 경우 히든 처리
    // 생리 기록이 하나라도 있으면 임신 확률 표시 가능
    if (periodCycles.isEmpty && expectedPeriodDays.isEmpty) {
      return null;
    }

    // 미래 날짜는 생리 예정일 3개월까지만 표시
    // 과거 날짜는 생리 기록이 있으면 무조건 표시
    final threeMonthsLater = today.add(const Duration(days: 90));
    if (day.isAfter(threeMonthsLater)) {
      return null; // 미래 3개월 이후는 표시하지 않음
    }
    // 과거 날짜는 생리 기록이 있으면 표시되므로 여기서는 체크하지 않음

    // 모든 생리 시작일 수집 (실제 + 예상)
    final allPeriodStarts = <DateTime>[];

    // 실제 생리 주기의 시작일 찾기 (생리 기록이 있으면 반드시 있음)
    for (final cycle in periodCycles) {
      allPeriodStarts.add(cycle.start);
    }

    // 예상 생리 주기의 시작일 찾기 (연속된 날짜 그룹의 첫 번째)
    if (expectedPeriodDays.isNotEmpty) {
      DateTime? lastDate;
      for (final date in expectedPeriodDays) {
        if (lastDate == null || date.difference(lastDate).inDays > 1) {
          allPeriodStarts.add(date);
        }
        lastDate = date;
      }
    }

    // 생리 시작일 기준 앞뒤 7일간 체크
    for (final start in allPeriodStarts) {
      final diff = day.difference(start).inDays;
      if (diff >= -7 && diff <= 7) {
        return '낮음';
      }
    }

    // 가임기 체크 (실제 + 예상)
    // 생리 기록이 있으면 가임기가 계산되므로 체크 가능
    final allFertileDays = [...fertileWindowDays, ...expectedFertileWindowDays];
    for (final fertileDay in allFertileDays) {
      if (_sameDay(fertileDay, day)) {
        return '높음';
      }
    }

    // 그 외 날짜는 "보통" (생리 기록이 있으면 항상 표시)
    return '보통';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFffff),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDay!.month}월 ${selectedDay!.day}일 ${_weekdayLabel(selectedDay!)}요일',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final probability = _calculatePregnancyProbability(selectedDay);

              if (probability == null) {
                return const SizedBox.shrink(); // 범위 밖이면 표시하지 않음
              }

              // 색상과 텍스트 결정
              Color circleColor;
              String text;

              switch (probability) {
                case '낮음':
                  circleColor = const Color(0xFFC5C5C5); // 회색
                  text = '임신 확률 낮음';
                  break;
                case '높음':
                  circleColor = const Color(0xFFA7C4A0); // 녹색
                  text = '임신 확률 높음';
                  break;
                default: // '보통'
                  circleColor = const Color(0xFFFFD966); // 노란색
                  text = '임신 확률 보통';
                  break;
              }

              return Row(
                children: [
                  Row(
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9E7E74),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  icon: Icons.invert_colors,
                  label: '생리 시작',
                  selected: isStartSelected,
                  onTap: onPeriodStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToggleChip(
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
}

// ============================================================================
// [위젯 클래스] 뱃지 컴포넌트 (예: "생리 예정일 5일전")
// ============================================================================
class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Badge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 14, color: fg)),
    );
  }
}

// ============================================================================
// [위젯 클래스] 토글 칩 (생리 시작/종료 버튼)
// ============================================================================
class _ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selected;
    final Color fillColor = isSelected
        ? const Color(0xFFD32F2F)
        : const Color(0xFFFFEBEE);
    final Color borderColor = isSelected
        ? const Color(0xFFD32F2F)
        : const Color(0xFFD32F2F).withValues(alpha: 0.3);
    final Color textColor = isSelected ? Colors.white : const Color(0xFF8D5656);
    final Color iconBg = isSelected
        ? Colors.white.withValues(alpha: 0.2)
        : const Color(0xFFFFEBEE);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: textColor),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// [위젯 클래스] 증상 기록 섹션 (카테고리별 증상 칩들)
// ============================================================================
class _SymptomSection extends StatelessWidget {
  const _SymptomSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Category(
          title: '증상',
          groups: [
            [
              _ChipData('두통', false),
              _ChipData('어깨', true),
              _ChipData('허리', false),
              _ChipData('생리통', false),
              _ChipData('팔', false),
              _ChipData('다리', true),
            ],
          ],
        ),
        SizedBox(height: 12),
        _Category(
          title: '소화',
          groups: [
            [
              _ChipData('변비', false),
              _ChipData('설사', false),
              _ChipData('가스/복부팽만', false),
              _ChipData('메스꺼움', false),
            ],
          ],
        ),
        SizedBox(height: 12),
        _Category(
          title: '컨디션',
          groups: [
            [
              _ChipData('피로', false),
              _ChipData('집중력 저하', false),
              _ChipData('불면증', false),
            ],
            [
              _ChipData('식욕', false),
              _ChipData('성욕', false),
              _ChipData('분비물', false),
              _ChipData('질건조', true),
              _ChipData('질가려움', false),
            ],
            [
              _ChipData('피부 건조', true),
              _ChipData('피부 가려움', true),
              _ChipData('뾰루지', false),
            ],
          ],
        ),
        SizedBox(height: 12),
        _Category(
          title: '기분',
          groups: [
            [
              _ChipData('행복', false),
              _ChipData('불안', false),
              _ChipData('우울', false),
              _ChipData('슬픔', false),
              _ChipData('분노', false),
            ],
          ],
        ),
        SizedBox(height: 12),
        _Category(
          title: '기타',
          groups: [
            [_ChipData('관계', false), _ChipData('메모', false)],
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// [위젯 클래스] 증상 카테고리 (제목 + 증상 칩 그룹)
// ============================================================================
class _Category extends StatelessWidget {
  final String title;
  final List<List<_ChipData>> groups;

  const _Category({required this.title, required this.groups});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in groups) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: row.map((chip) => _SymptomChip(data: chip)).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ============================================================================
// [데이터 클래스] 증상 칩 데이터
// ============================================================================
class _ChipData {
  final String label;
  final bool selected;

  const _ChipData(this.label, this.selected);
}

// ============================================================================
// [위젯 클래스] 증상 칩 (개별 증상 표시)
// ============================================================================
class _SymptomChip extends StatelessWidget {
  final _ChipData data;

  const _SymptomChip({required this.data});

  @override
  Widget build(BuildContext context) {
    final selected = data.selected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFEBEE) : Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFFD32F2F) : const Color(0xFFEEEEEE),
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        data.label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? const Color(0xFFD32F2F) : const Color(0xFF8D5656),
        ),
      ),
    );
  }
}

// ============================================================================
// [위젯 클래스] 하단 네비게이션 바
// ============================================================================
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFC),
        border: const Border(top: BorderSide(color: Color(0xFFFFEBEE))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _NavItem(icon: Icons.home, label: '홈', selected: true),
              _NavAdd(),
              _NavItem(icon: Icons.insights, label: '리포트', selected: false),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// [위젯 클래스] 네비게이션 아이템 (홈, 리포트)
// ============================================================================
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFD32F2F) : const Color(0xFF8D5656);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// [위젯 클래스] 네비게이션 추가 버튼 (가운데 원형 버튼)
// ============================================================================
class _NavAdd extends StatelessWidget {
  const _NavAdd();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFEBEE)),
      ),
      child: const Icon(Icons.event_note, color: Colors.white, size: 24),
    );
  }
}
