import 'package:red_time_app/models/period_cycle.dart';

class CalendarDerivedData {
  final List<DateTime> fertileWindowDays;
  final DateTime? ovulationDay;
  final List<DateTime> ovulationDays;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> expectedFertileWindowDays;
  final DateTime? expectedOvulationDay;

  CalendarDerivedData({
    required this.fertileWindowDays,
    required this.ovulationDay,
    required this.ovulationDays,
    required this.expectedPeriodDays,
    required this.expectedFertileWindowDays,
    required this.expectedOvulationDay,
  });
}

class CalendarService {
  const CalendarService();

  // 중앙값: 변동성이 큰 구간 평균보다 튀는 값의 영향을 줄여 안정화
  int _medianInt(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  // Trimmed Mean: 최소/최대 한 개씩 제외해 이상치 영향 완화
  int _trimmedMean(List<int> values) {
    if (values.isEmpty) return 0;
    if (values.length < 3) {
      return values.reduce((a, b) => a + b) ~/ values.length;
    }
    final sorted = [...values]..sort();
    final trimmed = sorted.sublist(1, sorted.length - 1);
    return trimmed.reduce((a, b) => a + b) ~/ trimmed.length;
  }

  void ensureDefaultEnd(List<PeriodCycle> cycles, int idx) {
    if (idx < 0 || idx >= cycles.length) return;
    final cycle = cycles[idx];
    if (cycle.end == null || cycle.end!.isBefore(cycle.start)) {
      cycle.end = cycle.start.add(const Duration(days: 4));
    }
  }

  List<DateTime> computePeriodDays(List<PeriodCycle> cycles) {
    final set = <DateTime>{};
    for (final c in cycles) {
      set.addAll(c.toDays());
    }
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  CalendarDerivedData computeDerivedFertility({
    required List<PeriodCycle> periodCycles,
  }) {
    if (periodCycles.isEmpty) {
      return CalendarDerivedData(
        fertileWindowDays: const [],
        ovulationDay: null,
        ovulationDays: const [],
        expectedPeriodDays: const [],
        expectedFertileWindowDays: const [],
        expectedOvulationDay: null,
      );
    }

    final sorted = [...periodCycles]
      ..sort((a, b) => a.start.compareTo(b.start));
    // intervals: "각 생리 시작일 사이의 일 수" 목록 → 주기 길이 추정에 사용
    //   예) 12/1 시작, 다음 주기 12/29 시작 → 간격 28일 기록
    final intervals = <int>[];
    // durations: 각 생리 구간 길이(시작~끝) → 생리 기간 중앙값 산출에 사용
    //   예) 12/1~12/5 → 5일 기록
    final durations = <int>[];
    for (final c in sorted) {
      durations.add(c.end != null ? c.end!.difference(c.start).inDays + 1 : 1);
    }

    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].start.difference(sorted[i - 1].start).inDays;
      if (diff > 0) intervals.add(diff);
    }

    // cycleLength: 예측에 쓰는 주기 길이
    // 1) intervals(주기 간격)의 trimmed mean → 이상치 완화
    // 2) clamp 21~35일 → 비현실적 짧/긴 주기 배제
    //    - clamp: 값이 너무 작거나 크지 않게 최소/최대 범위로 잘라냄
    int cycleLength;
    if (intervals.isNotEmpty) {
      final trimmed = _trimmedMean(intervals);
      cycleLength = trimmed == 0 ? 28 : trimmed;
    } else {
      cycleLength = 28;
    }
    // 주기가 매우 짧은 경우(19일 등)도 지원하기 위해 범위 확장
    cycleLength = cycleLength.clamp(15, 45);

    // periodDuration: 실제 생리 기간을 대표하는 값 (durations 중앙값)
    final periodDuration = durations.isEmpty ? 1 : _medianInt(durations);

    var fertileWindowDays = <DateTime>[];
    DateTime? ovulationDay;
    var ovulationDays = <DateTime>[];

    // 황체기: 생물학적 표준인 14일로 고정
    const int luteal = 14;
    // 배란은 생리 시작일로부터 최소 7일째(오프셋 6일) 이후여야 함
    final int targetDay = (cycleLength - luteal).clamp(6, cycleLength);

    for (int i = 0; i < sorted.length; i++) {
      final cycle = sorted[i];
      DateTime cycleOvulation;

      // 만약 다음 기록이 있다면, 다음 기록의 시작일로부터 14일 전을 배란일로 계산 (실제 데이터 반영)
      if (i < sorted.length - 1) {
        final nextStart = sorted[i + 1].start;
        cycleOvulation = DateTime(
          nextStart.year,
          nextStart.month,
          nextStart.day,
        ).subtract(const Duration(days: luteal));

        // 배란일 하한선 적용: 최소 시작일로부터 7일째(6일 오프셋)
        final minOv = cycle.start.add(const Duration(days: 6));
        if (cycleOvulation.isBefore(minOv)) {
          cycleOvulation = minOv;
        }
      } else {
        // 마지막 기록은 평균 주기(targetDay)를 사용하여 예측
        cycleOvulation = cycle.start.add(Duration(days: targetDay));
      }

      ovulationDays.add(cycleOvulation);
      if (ovulationDay == null || cycleOvulation.isAfter(ovulationDay)) {
        ovulationDay = cycleOvulation;
      }

      // 가임기 계산: 배란일 기준 -4일 ~ +2일 (총 7일, 원래 설정으로 복원)
      final startWindow = cycleOvulation.subtract(const Duration(days: 4));
      for (int j = 0; j < 7; j++) {
        fertileWindowDays.add(
          DateTime(startWindow.year, startWindow.month, startWindow.day + j),
        );
      }
    }

    fertileWindowDays = fertileWindowDays.toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    ovulationDays = ovulationDays.toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    final currentCycle = sorted.last; // 가장 최근 주기

    // 예측 세트: 다음 3회 주기의 예상 생리/가임/배란
    var expectedPeriodDays = <DateTime>[]; // 예상 생리 구간 전체 날짜
    var expectedFertileWindowDays = <DateTime>[]; // 예상 가임기 날짜
    DateTime? expectedOvulationDay; // 가장 가까운 예상 배란일(다음 주기)

    // nextPeriodStart: 다음 생리 예상 시작일(현재 주기 시작 + cycleLength)
    DateTime nextPeriodStart = currentCycle.start.add(
      Duration(days: cycleLength),
    );

    for (int month = 0; month < 3; month++) {
      for (int i = 0; i < periodDuration; i++) {
        expectedPeriodDays.add(
          DateTime(
            nextPeriodStart.year,
            nextPeriodStart.month,
            nextPeriodStart.day + i,
          ),
        );
      }

      // expectedOvulation(배란 예상일) 계산 방법:
      // 1) cycleLength: 최근 간격 trimmed mean 후 15~45일로 제한
      // 2) luteal: 14일 고정
      // 3) targetDay: cycleLength - luteal, 단 최소 7일째(오프셋 6) 보장
      // 4) expectedOvulation = nextPeriodStart + targetDay
      final expectedOvulation = nextPeriodStart.add(Duration(days: targetDay));
      if (month == 0) {
        expectedOvulationDay = expectedOvulation;
      }

      // expectedStartWindow: 예측 배란일 기준 -4일 ~ +2일 (총 7일)
      final expectedStartWindow = expectedOvulation.subtract(
        const Duration(days: 4),
      );
      for (int i = 0; i < 7; i++) {
        expectedFertileWindowDays.add(
          DateTime(
            expectedStartWindow.year,
            expectedStartWindow.month,
            expectedStartWindow.day + i,
          ),
        );
      }

      nextPeriodStart = nextPeriodStart.add(Duration(days: cycleLength));
    }

    return CalendarDerivedData(
      fertileWindowDays: fertileWindowDays,
      ovulationDay: ovulationDay,
      ovulationDays: ovulationDays,
      expectedPeriodDays: expectedPeriodDays,
      expectedFertileWindowDays: expectedFertileWindowDays,
      expectedOvulationDay: expectedOvulationDay,
    );
  }
}
