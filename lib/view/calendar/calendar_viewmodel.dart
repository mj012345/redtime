import 'package:flutter/foundation.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/models/symptom_category.dart';
import 'package:red_time_app/repositories/period_repository.dart';
import 'package:red_time_app/repositories/symptom_repository.dart';
import 'package:red_time_app/services/calendar_service.dart';

class CalendarViewModel extends ChangeNotifier {
  final String? userId; // 사용자 ID 저장 (Repository 타입 확인용)

  CalendarViewModel({
    PeriodRepository? periodRepository,
    SymptomRepository? symptomRepository,
    CalendarService? calendarService,
  }) : _periodRepo = periodRepository ?? InMemoryPeriodRepository(),
       _symptomRepo = symptomRepository ?? InMemorySymptomRepository(),
       _calendarService = calendarService ?? const CalendarService(),
       userId = (periodRepository is FirebasePeriodRepository)
           ? (periodRepository as FirebasePeriodRepository).userId
           : null {
    _initialize();
  }

  /// 비동기 초기화 (Firebase Repository 사용 시)
  Future<void> _initialize() async {
    // Firebase Repository인 경우 비동기 로드, 아니면 동기 로드
    if (_symptomRepo is FirebaseSymptomRepository) {
      _symptomSelections = await (_symptomRepo as FirebaseSymptomRepository)
          .loadAsync();
    } else {
      _symptomSelections = _symptomRepo.loadSelections();
    }

    if (_periodRepo is FirebasePeriodRepository) {
      periodCycles = await (_periodRepo as FirebasePeriodRepository)
          .loadAsync();
    } else {
      periodCycles = _periodRepo.load();
    }

    _recomputeSymptomRecordDays();
    _recomputePeriodDays();
    notifyListeners();
  }

  // 기본 날짜 상태
  final DateTime today = DateTime.now();
  DateTime? selectedDay = DateTime.now();
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // 주기 관련 상태
  List<DateTime> periodDays = [];
  List<PeriodCycle> periodCycles = [];
  int? activeCycleIndex;

  // 가임기/배란/예상값
  List<DateTime> fertileWindowDays = [];
  DateTime? ovulationDay;
  List<DateTime> ovulationDays = [];
  List<DateTime> expectedPeriodDays = [];
  List<DateTime> expectedFertileWindowDays = [];
  DateTime? expectedOvulationDay;

  // 증상 기록
  List<DateTime> symptomRecordDays = [];
  late final Map<String, Set<String>> _symptomSelections;
  final PeriodRepository _periodRepo;
  final SymptomRepository _symptomRepo;
  final CalendarService _calendarService;

  // 증상 카테고리 정의
  final List<SymptomCategory> symptomCatalog = const [
    SymptomCategory('통증', [
      ['두통', '어깨', '허리', '생리통', '팔', '다리'],
    ]),
    SymptomCategory('소화', [
      ['변비', '설사', '가스/복부팽만', '메스꺼움'],
    ]),
    SymptomCategory('컨디션', [
      ['피로', '집중력 저하', '불면증'],
      ['식욕', '성욕', '분비물', '질건조', '질가려움'],
      ['피부 건조', '피부 가려움', '뾰루지'],
    ]),
    SymptomCategory('기분', [
      ['행복', '불안', '우울', '슬픔', '분노'],
    ]),
    SymptomCategory('기타', [
      ['관계', '메모'],
    ]),
  ];

  // 날짜 키 변환 (yyyy-MM-dd)
  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  // 유틸
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // 증상 선택 상태
  Set<String> selectedSymptomsFor(DateTime? day) {
    if (day == null) return <String>{};
    return _symptomSelections[_dateKey(day)] ?? <String>{};
  }

  void toggleSymptom(String label) {
    if (selectedDay == null) return;
    final key = _dateKey(selectedDay!);
    final current = {...(_symptomSelections[key] ?? <String>{})};
    if (current.contains(label)) {
      current.remove(label);
    } else {
      current.add(label);
    }

    if (current.isEmpty) {
      _symptomSelections.remove(key);
    } else {
      _symptomSelections[key] = current;
    }

    _recomputeSymptomRecordDays();
    _persistSymptoms();
    notifyListeners();
  }

  void _recomputeSymptomRecordDays() {
    symptomRecordDays = _symptomSelections.keys.map(_parseDateKey).toList()
      ..sort((a, b) => a.compareTo(b));
  }

  // 날짜 선택/월 이동
  void selectDay(DateTime day) {
    selectedDay = DateTime(day.year, day.month, day.day);
    if (day.month != currentMonth.month || day.year != currentMonth.year) {
      currentMonth = DateTime(day.year, day.month);
    }
    notifyListeners();
  }

  void goPrevMonth() {
    currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    notifyListeners();
  }

  void goNextMonth() {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    notifyListeners();
  }

  void goToday() {
    currentMonth = DateTime(today.year, today.month);
    selectedDay = today;
    notifyListeners();
  }

  // 생리 시작/종료
  void setPeriodStart() {
    if (selectedDay == null) {
      print('⚠️ [CalendarViewModel] setPeriodStart: selectedDay가 null입니다.');
      return;
    }
    print(
      '🔴 [CalendarViewModel] setPeriodStart() 호출됨 - 선택일: ${selectedDay!.toIso8601String()}',
    );
    final sd = DateTime(
      selectedDay!.year,
      selectedDay!.month,
      selectedDay!.day,
    );

    int? existingIdx = _findCycleIndexContaining(sd);
    if (existingIdx != null && _sameDay(periodCycles[existingIdx].start, sd)) {
      periodCycles.removeAt(existingIdx);
      if (activeCycleIndex != null && activeCycleIndex == existingIdx) {
        activeCycleIndex = null;
      } else if (activeCycleIndex != null && activeCycleIndex! > existingIdx) {
        activeCycleIndex = activeCycleIndex! - 1;
      }
      _recomputePeriodDays();
      return;
    }

    if (activeCycleIndex != null &&
        _sameDay(periodCycles[activeCycleIndex!].start, sd)) {
      periodCycles.removeAt(activeCycleIndex!);
      activeCycleIndex = null;
      _recomputePeriodDays();
      return;
    }

    // 시작일 설정 대상 주기 선택 우선순위:
    // 1) 선택일을 포함하는 주기
    // 2) 시작일이 선택일보다 뒤지만 5일 이내(앞당기기)에서 가장 가까운 주기
    // 3) 시작일이 선택일과 가장 가까운 이전(또는 동일)이고 5일 이내인 주기
    final idx = _findCycleIndexForStart(sd);
    if (idx != null) {
      final cycle = periodCycles[idx];
      cycle.start = sd;
      if (cycle.end != null && cycle.end!.isBefore(cycle.start)) {
        cycle.end = cycle.start;
      }
      _ensureDefaultEnd(idx);
      activeCycleIndex = idx;
      _recomputePeriodDays();
      return;
    }

    periodCycles.add(PeriodCycle(sd, null));
    activeCycleIndex = periodCycles.length - 1;
    _ensureDefaultEnd(activeCycleIndex!);
    _recomputePeriodDays();
  }

  void setPeriodEnd() {
    if (selectedDay == null) {
      print('⚠️ [CalendarViewModel] setPeriodEnd: selectedDay가 null입니다.');
      return;
    }
    print(
      '🔴 [CalendarViewModel] setPeriodEnd() 호출됨 - 선택일: ${selectedDay!.toIso8601String()}',
    );
    final sd = DateTime(
      selectedDay!.year,
      selectedDay!.month,
      selectedDay!.day,
    );

    // 종료 설정 대상 주기 선택 우선순위:
    // 1) 선택일을 포함하는 주기
    // 2) 시작일이 선택일과 가장 가깝게 이전(또는 동일)이고, 5일 이내인 주기
    // 3) 기존 activeCycle
    int? idx = _findCycleIndexForEnd(sd);
    idx ??= activeCycleIndex;

    if (idx == null) {
      periodCycles.add(PeriodCycle(sd, sd));
      activeCycleIndex = periodCycles.length - 1;
      _recomputePeriodDays();
      return;
    }

    final cycle = periodCycles[idx];
    if (cycle.contains(sd)) {
      if (cycle.end != null && _sameDay(cycle.end!, sd)) {
        cycle.end = cycle.start;
      } else {
        cycle.end = sd;
      }
    } else if (sd.isBefore(cycle.start)) {
      cycle.start = sd;
      cycle.end = sd;
    } else {
      cycle.end = sd;
    }
    activeCycleIndex = idx;
    _recomputePeriodDays();
  }

  void _ensureDefaultEnd(int idx) =>
      _calendarService.ensureDefaultEnd(periodCycles, idx);

  void _recomputePeriodDays() {
    print(
      '🔄 [CalendarViewModel] _recomputePeriodDays() 호출됨 - 주기 개수: ${periodCycles.length}',
    );
    periodDays = _calendarService.computePeriodDays(periodCycles);
    final derived = _calendarService.computeDerivedFertility(
      periodCycles: periodCycles,
    );
    fertileWindowDays = derived.fertileWindowDays;
    ovulationDay = derived.ovulationDay;
    ovulationDays = derived.ovulationDays;
    expectedPeriodDays = derived.expectedPeriodDays;
    expectedFertileWindowDays = derived.expectedFertileWindowDays;
    expectedOvulationDay = derived.expectedOvulationDay;

    // 생리 주기 변경 시 Firebase에 저장
    print('💾 [CalendarViewModel] Firebase에 생리 주기 저장 시작...');
    print('💾 [CalendarViewModel] Repository 타입: ${_periodRepo.runtimeType}');
    _periodRepo.save(periodCycles);

    notifyListeners();
  }

  // 검색 유틸
  /// 종료일 지정에 쓰는 주기 탐색:
  /// - 선택일을 포함하는 주기
  /// - 포함하지 않으면, 시작일이 선택일과 가장 가깝게 이전(또는 동일)이고 5일 이내인 주기
  int? _findCycleIndexForEnd(DateTime d) {
    int? bestIdx;
    int bestGap = 9999;
    for (int i = 0; i < periodCycles.length; i++) {
      final c = periodCycles[i];
      if (c.contains(d)) return i;
      final gap = d.difference(c.start).inDays;
      if (gap >= 0 && gap <= 5) {
        if (gap < bestGap ||
            (gap == bestGap && c.start.isAfter(periodCycles[bestIdx!].start))) {
          bestIdx = i;
          bestGap = gap;
        }
      }
    }
    return bestIdx;
  }

  /// 시작일 지정에 쓰는 주기 탐색:
  /// - 선택일을 포함하는 주기
  /// - 포함하지 않으면, 선택일이 주기 시작보다 최대 5일 앞에 있을 때(앞당기기) 가장 가까운 주기
  /// - 그래도 없으면, 시작일이 선택일과 가장 가깝게 이전(또는 동일)이고 5일 이내인 주기
  int? _findCycleIndexForStart(DateTime d) {
    int? bestAfterIdx;
    int bestAfterGap = 9999;
    int? bestBeforeIdx;
    int bestBeforeGap = 9999;

    for (int i = 0; i < periodCycles.length; i++) {
      final c = periodCycles[i];
      if (c.contains(d)) return i;

      final gapBeforeStart = c.start.difference(d).inDays; // 양수면 d가 앞쪽
      if (gapBeforeStart > 0 && gapBeforeStart <= 5) {
        // d가 주기 시작보다 앞에 있으면서 5일 이내 → 앞당기기 후보
        if (gapBeforeStart < bestAfterGap ||
            (gapBeforeStart == bestAfterGap &&
                c.start.isBefore(periodCycles[bestAfterIdx!].start))) {
          bestAfterIdx = i;
          bestAfterGap = gapBeforeStart;
        }
      } else {
        final gap = d.difference(c.start).inDays;
        if (gap >= 0 && gap <= 5) {
          if (gap < bestBeforeGap ||
              (gap == bestBeforeGap &&
                  c.start.isAfter(periodCycles[bestBeforeIdx!].start))) {
            bestBeforeIdx = i;
            bestBeforeGap = gap;
          }
        }
      }
    }

    // 앞당기기 후보 우선, 없으면 이전/동일 후보
    return bestAfterIdx ?? bestBeforeIdx;
  }

  int? _findCycleIndexContaining(DateTime d) {
    for (int i = 0; i < periodCycles.length; i++) {
      if (periodCycles[i].contains(d)) return i;
    }
    return null;
  }

  bool isSelectedDayStart() {
    if (selectedDay == null) return false;
    for (final c in periodCycles) {
      if (_sameDay(c.start, selectedDay!)) return true;
    }
    return false;
  }

  bool isSelectedDayEnd() {
    if (selectedDay == null) return false;
    for (final c in periodCycles) {
      final end = c.end ?? c.start;
      final realEnd = end.isBefore(c.start) ? c.start : end;
      if (_sameDay(realEnd, selectedDay!)) return true;
    }
    return false;
  }

  void _persistSymptoms() {
    _symptomRepo.saveSelections(_symptomSelections);
  }
}
