import 'dart:async';
import 'package:flutter/material.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/models/symptom_category.dart';
import 'package:red_time_app/repositories/period_repository.dart';
import 'package:red_time_app/repositories/symptom_repository.dart';
import 'package:red_time_app/services/calendar_service.dart';

class CalendarViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final String? userId; // 사용자 ID 저장 (Repository 타입 확인용)

  // 디바운싱 타이머 (1.5초 지연)
  final Map<String, Timer> _symptomSaveTimers = {}; // 날짜별 증상 저장 타이머
  Timer? _periodSaveTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 1500);

  CalendarViewModel({
    PeriodRepository? periodRepository,
    SymptomRepository? symptomRepository,
    CalendarService? calendarService,
    bool isNewLogin = false,
  }) : _periodRepo = periodRepository ?? InMemoryPeriodRepository(),
       _symptomRepo = symptomRepository ?? InMemorySymptomRepository(),
       _calendarService = calendarService ?? const CalendarService(),
       userId = (periodRepository is FirebasePeriodRepository)
           ? periodRepository.userId
           : null,
       _isNewLogin = isNewLogin {
    // 비동기 초기화를 지연시켜 앱 시작을 블로킹하지 않도록 함
    Future.microtask(() => _initialize(forceRefresh: _isNewLogin));
    WidgetsBinding.instance.addObserver(this);
  }

  final bool _isNewLogin;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPendingSaves();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드로 가거나 종료될 때 대기 중인 저장 작업 즉시 수행
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _flushPendingSaves();
    }
  }

  /// 대기 중인 모든 저장 작업을 즉시 수행
  void _flushPendingSaves() {
    // 증상 저장 Flush
    for (final dateKey in _symptomSaveTimers.keys) {
      _symptomSaveTimers[dateKey]?.cancel();
      final symptoms = _symptomSelections[dateKey];
      if (symptoms != null) { // 삭제된 경우 null일 수 있음 (여기서는 remove하지 않으므로 체크)
         // 빈 set이라도 저장이 필요하면 저장 (symptomsSelections에 있다는 것은 의미가 있음)
        _symptomRepo.saveSymptomForDate(dateKey, symptoms);
      }
    }
    _symptomSaveTimers.clear();

    // 주기 저장 Flush
    if (_periodSaveTimer != null) {
      _periodSaveTimer!.cancel();
      _periodSaveTimer = null;
      _performPeriodSave();
    }
  }

  /// 비동기 초기화 (Firebase Repository 사용 시)
  /// 로그인 시: forceRefresh: true (서버에서 최신 데이터)
  /// 앱 재시작 시: forceRefresh: false (캐시 사용, 비용 절감)
  Future<void> _initialize({bool forceRefresh = false}) async {
    await refresh(forceRefresh: forceRefresh);
  }

  /// 데이터 새로고침 (리프레시용)
  Future<void> refresh({bool forceRefresh = false}) async {
    try {
      // 리프레시 시 기존 데이터를 먼저 초기화 (Firebase에서 빈 데이터가 올 수 있으므로)
      Map<String, Set<String>> newSymptomSelections = {};
      List<PeriodCycle> newPeriodCycles = [];

      // Firebase Repository인 경우 캐시 우선 사용 (기본값) 또는 서버에서 강제 읽기
      Map<String, String> newMemos = {};
      if (_symptomRepo is FirebaseSymptomRepository) {
        final repo = _symptomRepo;
        // 통합 읽기: 증상과 메모를 한 번에 읽기 (중복 읽기 제거)
        final result = await repo.loadAllAsync(forceRefresh: forceRefresh);
        newSymptomSelections = result.symptoms;
        newMemos = result.memos;
      } else {
        newSymptomSelections = _symptomRepo.loadSelections();
        newMemos = _symptomRepo.loadMemos();
      }

      if (_periodRepo is FirebasePeriodRepository) {
        newPeriodCycles = await (_periodRepo).loadAsync(
          forceRefresh: forceRefresh,
        );
      } else {
        newPeriodCycles = _periodRepo.load();
      }

      // 가져온 데이터로 덮어쓰기 (빈 데이터여도)
      _symptomSelections = newSymptomSelections;
      _memos = newMemos;
      periodCycles = newPeriodCycles;
      // 로드한 상태를 저장 상태로 업데이트 (깊은 복사)
      _savedPeriodCycles = newPeriodCycles
          .map(
            (c) => PeriodCycle(
              DateTime(c.start.year, c.start.month, c.start.day),
              c.end != null
                  ? DateTime(c.end!.year, c.end!.month, c.end!.day)
                  : null,
            ),
          )
          .toList();

      _recomputeSymptomRecordDays();
      _recomputePeriodDays(shouldSave: false); // 데이터 로드 시에는 저장하지 않음
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // 에러 발생 시 빈 데이터로 초기화 (기존 데이터 유지하지 않음)
      _symptomSelections = {};
      _memos = {};
      periodCycles = [];
      _savedPeriodCycles = [];
      _recomputeSymptomRecordDays();
      _recomputePeriodDays(shouldSave: false); // 데이터 로드 시에는 저장하지 않음
      _isInitialized = true;
      notifyListeners();
      rethrow; // 리프레시 실패를 호출자에게 알림
    }
  }

  // 기본 날짜 상태
  final DateTime today = DateTime.now();
  DateTime? selectedDay = DateTime.now();
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // 주기 관련 상태
  List<DateTime> periodDays = [];
  List<PeriodCycle> periodCycles = [];
  List<PeriodCycle> _savedPeriodCycles = []; // 마지막 저장된/로드된 상태 (메모리 추적용)
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
  Map<String, Set<String>> _symptomSelections = {}; // late final 제거, 초기값 설정
  Map<String, String> _memos = {}; // 날짜별 메모 저장
  bool _isInitialized = false; // 초기화 상태 추적
  final PeriodRepository _periodRepo;
  final SymptomRepository _symptomRepo;
  final CalendarService _calendarService;

  // 증상 카테고리 정의
  final List<SymptomCategory> symptomCatalog = const [
    SymptomCategory('통증', [
      ['좋음', '두통', '어깨', '등', '가슴', '허리', '생리통', '배란통', '팔', '다리', '관절'],
    ]),
    SymptomCategory('소화', [
      ['좋음', '변비', '설사', '가스', '메스꺼움'],
    ]),
    SymptomCategory('컨디션', [
      ['좋음', '오한', '발열', '몸살', '감기', '피로', '집중력저하', '불면증', '졸림', '식욕', '성욕'],
    ]),
    SymptomCategory('피부', [
      ['좋음', '뾰루지', '각질', '유분과다', '피부건조', '피부가려움'],
    ]),
    SymptomCategory('질상태', [
      ['좋음', '질분비물', '질건조', '질가려움', '질염'],
    ]),
    SymptomCategory('기분', [
      ['좋음', '짜증', '불안', '우울', '슬픔', '분노'],
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

  // 증기화 상태 확인
  bool get isInitialized => _isInitialized;

  // 증상 선택 상태
  Set<String> selectedSymptomsFor(DateTime? day) {
    if (day == null || !_isInitialized) return <String>{};
    return _symptomSelections[_dateKey(day)] ?? <String>{};
  }

  // 특정 날짜의 증상 개수 반환
  int getSymptomCountFor(DateTime? day) {
    if (day == null || !_isInitialized) return 0;
    final symptoms = _symptomSelections[_dateKey(day)];
    if (symptoms == null) return 0;
    // 메모가 있으면 증상 개수에 포함
    final memo = _memos[_dateKey(day)];
    final hasMemo = memo != null && memo.isNotEmpty;
    return symptoms.length + (hasMemo ? 1 : 0);
  }

  // 증상 데이터 전체 접근 (리포트용)
  Map<String, Set<String>> get symptomSelections =>
      Map<String, Set<String>>.from(
        _symptomSelections.map((k, v) => MapEntry(k, Set<String>.from(v))),
      );

  // 메모 데이터 전체 접근 (리포트용)
  Map<String, String> get memos => Map<String, String>.from(_memos);

  void toggleSymptom(String label) {
    if (selectedDay == null) return;
    final key = _dateKey(selectedDay!);
    final current = {...(_symptomSelections[key] ?? <String>{})};

    // "메모"는 예외 처리
    if (label == '메모') {
      if (current.contains(label)) {
        current.remove(label);
      } else {
        current.add(label);
      }
    } else {
      // label이 "Category/Symptom" 형식 (카테고리 이름에 슬래시가 포함될 수 있음)
      final lastSlashIndex = label.lastIndexOf('/');
      if (lastSlashIndex == -1) return; // 슬래시가 없으면 종료

      final category = label.substring(0, lastSlashIndex);
      final symptomName = label.substring(lastSlashIndex + 1);
      final isGoodSymptom = symptomName == '좋음';

      if (current.contains(label)) {
        // 이미 선택된 경우 제거
        current.remove(label);
      } else {
        // 새로 선택하는 경우
        if (isGoodSymptom) {
          // '좋음'을 선택하면 같은 카테고리의 다른 증상들만 제거
          current.removeWhere(
            (s) => s.startsWith('$category/') && !s.endsWith('/좋음'),
          );
          current.add(label);
        } else {
          // 다른 증상을 선택하면 같은 카테고리의 '좋음'만 제거
          current.removeWhere((s) => s == '$category/좋음');
          current.add(label);
        }
      }
    }

    if (current.isEmpty) {
      _symptomSelections.remove(key);
    } else {
      _symptomSelections[key] = current;
    }

    // 증상 저장/삭제 (디바운싱 적용)
    _persistSymptomForDate(key, current);

    _recomputeSymptomRecordDays();
    notifyListeners();
  }

  /// 증상 저장 디바운싱 (개별 날짜 단위)
  void _persistSymptomForDate(String dateKey, Set<String> symptoms) {
    _symptomSaveTimers[dateKey]?.cancel();
    _symptomSaveTimers[dateKey] = Timer(_debounceDelay, () {
      _performSymptomSaveForDate(dateKey, symptoms);
    });
  }

  /// 실제 증상 저장 수행 (개별 날짜)
  void _performSymptomSaveForDate(String dateKey, Set<String> symptoms) {
    _symptomSaveTimers[dateKey]?.cancel();
    _symptomSaveTimers.remove(dateKey);
    _symptomRepo.saveSymptomForDate(dateKey, symptoms);
  }

  // 메모 관련 메서드
  String? getMemoFor(DateTime? day) {
    if (day == null || !_isInitialized) return null;
    return _memos[_dateKey(day)];
  }

  void saveMemo(String memo) {
    if (selectedDay == null) return;
    final key = _dateKey(selectedDay!);

    if (memo.trim().isEmpty) {
      _memos.remove(key);
      _symptomRepo.deleteMemo(key);
    } else {
      _memos[key] = memo;
      _symptomRepo.saveMemo(key, memo);
    }

    _recomputeSymptomRecordDays();
    notifyListeners();
  }

  void deleteMemo() {
    if (selectedDay == null) return;
    final key = _dateKey(selectedDay!);
    _memos.remove(key);
    _symptomRepo.deleteMemo(key);
    _recomputeSymptomRecordDays();
    notifyListeners();
  }

  void _recomputeSymptomRecordDays() {
    // 증상 기록 날짜와 메모 기록 날짜를 합침
    final allRecordDays = <DateTime>{};

    // 증상 기록이 있는 날짜 추가
    for (final key in _symptomSelections.keys) {
      if (_symptomSelections[key]?.isNotEmpty == true) {
        allRecordDays.add(_parseDateKey(key));
      }
    }

    // 메모가 있는 날짜 추가
    for (final key in _memos.keys) {
      final memo = _memos[key];
      if (memo != null && memo.trim().isNotEmpty) {
        allRecordDays.add(_parseDateKey(key));
      }
    }

    symptomRecordDays = allRecordDays.toList()..sort((a, b) => a.compareTo(b));
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

  void setCurrentMonth(DateTime month) {
    if (currentMonth.year != month.year || currentMonth.month != month.month) {
      currentMonth = month;
      notifyListeners();
    }
  }

  // 생리 시작/종료
  void setPeriodStart() {
    if (selectedDay == null) {
      return;
    }
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
      return;
    }
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

  void _recomputePeriodDays({bool shouldSave = true}) {
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

    // 생리 주기 변경 시 Firebase에 저장 (디바운싱 적용)
    // 데이터 로드 시에는 저장하지 않음 (shouldSave: false)
    if (shouldSave) {
      _persistPeriods();
    }

    notifyListeners();
  }

  /// 주기 저장 디바운싱 (1.5초 지연)
  void _persistPeriods() {
    _periodSaveTimer?.cancel();
    _periodSaveTimer = Timer(_debounceDelay, () {
      _performPeriodSave();
    });
  }

  /// 실제 주기 저장 수행
  void _performPeriodSave() {
    _periodSaveTimer?.cancel();
    _periodSaveTimer = null;

    // 이전 상태와 비교하여 삭제할 시작일 계산
    final savedStartKeys = <String>{};
    for (final cycle in _savedPeriodCycles) {
      savedStartKeys.add(_dateKey(cycle.start));
    }

    final currentStartKeys = <String>{};
    for (final cycle in periodCycles) {
      currentStartKeys.add(_dateKey(cycle.start));
    }

    // 삭제할 시작일: 이전에 있었지만 현재는 없는 것
    final deleteStartDates = savedStartKeys
        .where((key) => !currentStartKeys.contains(key))
        .toSet();

    _periodRepo.save(periodCycles, deleteStartDates: deleteStartDates);

    // 저장 완료 후 현재 상태를 저장 상태로 업데이트
    _savedPeriodCycles = periodCycles
        .map(
          (c) => PeriodCycle(
            DateTime(c.start.year, c.start.month, c.start.day),
            c.end != null
                ? DateTime(c.end!.year, c.end!.month, c.end!.day)
                : null,
          ),
        )
        .toList();
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
}
