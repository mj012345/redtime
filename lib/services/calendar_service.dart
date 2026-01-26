import 'package:red_time_app/models/period_cycle.dart';

/// 캘린더에서 파생된 데이터를 담는 클래스
/// (가임기, 배란일, 예상 생리일 등)
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

/// 생리 주기 관련 계산을 담당하는 서비스 클래스
class CalendarService {
  const CalendarService();

  /// 중앙값 계산
  /// - 변동성이 큰 데이터에서 평균보다 이상치의 영향을 덜 받음
  /// - 리스트를 정렬한 후 중간 위치의 값을 반환
  int _medianInt(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// Trimmed Mean (절사 평균) 계산
  /// - 최소값과 최대값을 각각 하나씩 제외한 후 평균을 구함
  /// - 이상치의 영향을 완화하여 더 안정적인 평균값 산출
  /// - 3개 미만의 데이터는 일반 평균 사용
  int _trimmedMean(List<int> values) {
    if (values.isEmpty) return 0;
    if (values.length < 3) {
      return values.reduce((a, b) => a + b) ~/ values.length;
    }
    final sorted = [...values]..sort();
    final trimmed = sorted.sublist(1, sorted.length - 1);
    return trimmed.reduce((a, b) => a + b) ~/ trimmed.length;
  }

  /// 생리 주기의 종료일이 없거나 시작일보다 이전인 경우 기본값 설정
  /// - 종료일을 시작일로부터 4일 후로 설정 (일반적인 생리 기간)
  void ensureDefaultEnd(List<PeriodCycle> cycles, int idx) {
    if (idx < 0 || idx >= cycles.length) return;
    final cycle = cycles[idx];
    if (cycle.end == null || cycle.end!.isBefore(cycle.start)) {
      cycle.end = cycle.start.add(const Duration(days: 4));
    }
  }

  /// 모든 생리 주기의 날짜들을 하나의 리스트로 합침
  /// - 중복 제거 및 정렬된 날짜 리스트 반환
  List<DateTime> computePeriodDays(List<PeriodCycle> cycles) {
    final set = <DateTime>{};
    for (final c in cycles) {
      set.addAll(c.toDays());
    }
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  /// 생리 주기 데이터를 기반으로 가임기, 배란일, 예상 생리일 등을 계산
  /// 
  /// 계산 로직:
  /// 1. 주기 길이(cycleLength) 산출
  ///    - 각 생리 시작일 간격의 trimmed mean 사용
  ///    - 15~45일 범위로 제한하여 비현실적인 값 배제
  /// 
  /// 2. 생리 기간(periodDuration) 산출
  ///    - 각 주기의 시작~종료 일수의 중앙값 사용
  /// 
  /// 3. 배란일 계산
  ///    - 황체기 14일 고정 (생물학적 표준)
  ///    - 다음 주기가 있는 경우: 다음 시작일 - 14일
  ///    - 마지막 주기: 시작일 + (주기길이 - 14일)
  ///    - 단, 최소 시작일로부터 7일째 이후로 제한
  /// 
  /// 4. 가임기 계산
  ///    - 배란일 기준 -4일 ~ +2일 (총 7일)
  /// 
  /// 5. 예상 생리일 및 가임기 계산
  ///    - 다음 3개월의 예상 주기 계산
  ///    - 예상 생리일: 시작일만 표시
  ///    - 예상 가임기: 예상 배란일 기준 -4일 ~ +2일
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
    
    // intervals: 각 생리 시작일 사이의 일 수 (주기 길이 추정용)
    // 예) 12/1 시작, 다음 주기 12/29 시작 → 간격 28일
    final intervals = <int>[];
    
    // durations: 각 생리 기간 길이 (시작~종료)
    // 예) 12/1~12/5 → 5일
    final durations = <int>[];
    
    for (final c in sorted) {
      durations.add(c.end != null ? c.end!.difference(c.start).inDays + 1 : 1);
    }

    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].start.difference(sorted[i - 1].start).inDays;
      if (diff > 0) intervals.add(diff);
    }

    // 주기 길이 계산
    // - 최근 6개월(약 6개 간격)만 사용하여 현재 패턴 반영
    // - intervals의 trimmed mean 사용 (이상치 완화)
    // - 15~45일 범위로 제한 (비현실적인 짧거나 긴 주기 배제)
    int cycleLength;
    if (intervals.isNotEmpty) {
      // 디버그: 주기 패턴 출력
      print('📊 [주기 분석] 전체 간격: $intervals');
      
      // 최근 6개 간격만 사용 (약 6개월치 데이터)
      final recentIntervals = intervals.length > 6
          ? intervals.sublist(intervals.length - 6)
          : intervals;
      
      print('📊 [주기 분석] 최근 6개 간격: $recentIntervals');
      
      final trimmed = _trimmedMean(recentIntervals);
      cycleLength = trimmed == 0 ? 28 : trimmed;
      
      print('📊 [주기 분석] 계산된 주기 길이: $cycleLength일');
    } else {
      cycleLength = 28;
      print('📊 [주기 분석] 기록 없음, 기본값 28일 사용');
    }
    cycleLength = cycleLength.clamp(15, 45);

    // 생리 기간: durations의 중앙값
    final periodDuration = durations.isEmpty ? 1 : _medianInt(durations);

    var fertileWindowDays = <DateTime>[];
    DateTime? ovulationDay;
    var ovulationDays = <DateTime>[];

    // 황체기: 생물학적 표준인 14일로 고정
    const int luteal = 14;
    
    // 배란일 계산 기준: 생리 시작일로부터 (주기길이 - 황체기)일째
    // 단, 최소 7일째(오프셋 6일) 이후로 제한
    final int targetDay = (cycleLength - luteal).clamp(6, cycleLength);

    // 각 주기별 배란일 및 가임기 계산
    for (int i = 0; i < sorted.length; i++) {
      final cycle = sorted[i];
      DateTime cycleOvulation;

      if (i < sorted.length - 1) {
        // 다음 주기가 있는 경우: 다음 시작일로부터 14일 전을 배란일로 계산
        final nextStart = sorted[i + 1].start;
        cycleOvulation = DateTime(
          nextStart.year,
          nextStart.month,
          nextStart.day,
        ).subtract(const Duration(days: luteal));

        // 배란일 하한선 적용: 최소 시작일로부터 7일째
        final minOv = cycle.start.add(const Duration(days: 6));
        if (cycleOvulation.isBefore(minOv)) {
          cycleOvulation = minOv;
        }
      } else {
        // 마지막 주기: 평균 주기 길이를 사용하여 예측
        cycleOvulation = cycle.start.add(Duration(days: targetDay));
      }

      ovulationDays.add(cycleOvulation);
      if (ovulationDay == null || cycleOvulation.isAfter(ovulationDay)) {
        ovulationDay = cycleOvulation;
      }

      // 가임기: 배란일 기준 -4일 ~ +2일 (총 7일)
      final startWindow = cycleOvulation.subtract(const Duration(days: 4));
      for (int j = 0; j < 7; j++) {
        fertileWindowDays.add(
          DateTime(startWindow.year, startWindow.month, startWindow.day + j),
        );
      }
    }

    // 중복 제거 및 정렬
    fertileWindowDays = fertileWindowDays.toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    ovulationDays = ovulationDays.toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    final currentCycle = sorted.last;

    // 예상 생리일 및 가임기 계산 (다음 3개월)
    var expectedPeriodDays = <DateTime>[];
    var expectedFertileWindowDays = <DateTime>[];
    DateTime? expectedOvulationDay;

    // 다음 생리 예상 시작일
    DateTime nextPeriodStart = currentCycle.start.add(
      Duration(days: cycleLength),
    );

    for (int month = 0; month < 3; month++) {
      // 예상 생리일: 시작일만 표시
      expectedPeriodDays.add(
        DateTime(
          nextPeriodStart.year,
          nextPeriodStart.month,
          nextPeriodStart.day,
        ),
      );

      // 예상 배란일 계산
      final expectedOvulation = nextPeriodStart.add(Duration(days: targetDay));
      if (month == 0) {
        expectedOvulationDay = expectedOvulation;
      }

      // 예상 가임기: 예상 배란일 기준 -4일 ~ +2일 (총 7일)
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
