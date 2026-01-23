import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/calendar/calendar_viewmodel.dart';
import 'package:red_time_app/view/splash/splash_view.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';
import 'widgets/month_header.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/today_card.dart';
import 'widgets/symptom_section.dart';
import 'widgets/memo_bottom_sheet.dart';
import 'widgets/week_row.dart';

class CalendarView extends StatefulWidget {
  final bool isActive;
  const CalendarView({super.key, this.isActive = true});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late PageController _pageController;
  late ScrollController _scrollController;
  static const int _basePageIndex = 1000;
  DateTime? _lastSyncedMonth;
  bool _showStickyHeader = false;
  DateTime? _lastSelectedDay; // 마지막 선택된 날짜 (스크롤 계산용)

  @override
  void initState() {
    super.initState();
    // 초기 페이지 인덱스를 ViewModel의 현재 월 기준으로 설정
    final vm = context.read<CalendarViewModel>();
    final initialIndex = _getIndexFromMonth(vm.currentMonth, vm.today);
    
    _pageController = PageController(initialPage: initialIndex);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 스크롤 위치에 따라 고정 헤더 표시 여부 결정
  void _onScroll() {
    if (_lastSelectedDay == null) return;

    final scrollOffset = _scrollController.offset;
    final shouldShow = _isSelectedWeekOutOfView(scrollOffset, _lastSelectedDay);

    if (_showStickyHeader != shouldShow) {
      setState(() {
        _showStickyHeader = shouldShow;
      });
    }
  }

  /// 선택한 주간이 화면에서 벗어났는지 확인
  bool _isSelectedWeekOutOfView(double scrollOffset, DateTime? selectedDay) {
    if (selectedDay == null) return false;

    const headerHeight = 26.0;
    const spacing = AppSpacing.lg;
    const cellHeight = 40.0;
    const lineHeight = 1.0;
    const rowHeight = cellHeight + lineHeight;

    // 선택한 날짜가 포함된 주가 달력 그리드에서 몇 번째 주인지 계산
    final firstDay = DateTime(selectedDay.year, selectedDay.month, 1);
    final startWeekday = firstDay.weekday;
    final startOffset = startWeekday % 7;
    final startDate = firstDay.subtract(Duration(days: startOffset));

    // 선택한 날짜가 달력 그리드에서 몇 번째 날인지 계산
    final daysFromStart = selectedDay.difference(startDate).inDays;
    final weekIndex = daysFromStart ~/ 7;

    // 선택한 주의 Y 위치 계산
    final weekYPosition = headerHeight + spacing + (weekIndex * rowHeight);

    // 스크롤 오프셋이 선택한 주의 위치를 넘어갔는지 확인
    // 약간의 여유를 두기 위해 rowHeight만큼 더 확인
    return scrollOffset > weekYPosition + rowHeight;
  }

  /// 최대 달력 높이 반환 (6주 달력 기준)
  double _getMaxCalendarHeight() {
    const headerHeight = 22.0; // 요일 헤더 (텍스트 높이 + 여백)
    const spacing = AppSpacing.xs; // 요일과 날짜 사이 간격
    const cellHeight = 45.0;
    const maxRowCount = 6;

    return headerHeight + spacing + (maxRowCount * cellHeight);
  }

  /// 선택된 날짜가 포함된 주를 계산
  List<DateTime> _getWeekForDate(DateTime? date) {
    if (date == null) return [];

    final weekday = date.weekday % 7;
    final weekStart = date.subtract(Duration(days: weekday));

    return List.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      return DateTime(day.year, day.month, day.day);
    });
  }

  /// 페이지 인덱스를 DateTime(년, 월)로 변환
  DateTime _getMonthFromIndex(int index, DateTime today) {
    final baseMonth = DateTime(today.year, today.month);
    final monthOffset = index - _basePageIndex;
    return DateTime(baseMonth.year, baseMonth.month + monthOffset);
  }

  /// DateTime(년, 월)을 페이지 인덱스로 변환
  int _getIndexFromMonth(DateTime month, DateTime today) {
    final baseMonth = DateTime(today.year, today.month);
    final monthDiff =
        (month.year - baseMonth.year) * 12 + (month.month - baseMonth.month);
    return _basePageIndex + monthDiff;
  }

  /// 페이지 이동 헬퍼
  void _jumpToPage(int offset) {
    if (_pageController.hasClients) {
      // 현재 페이지를 기준으로 상대적 이동
      final currentPage = _pageController.page?.round() ?? _basePageIndex;
      _pageController.jumpToPage(currentPage + offset);
    }
  }

  /// 메모 존재 여부 확인
  bool _hasMemo(CalendarViewModel vm, DateTime? day) {
    final memo = vm.getMemoFor(day);
    return memo != null && memo.isNotEmpty;
  }

  /// 메모 바텀시트 표시
  void _showMemoBottomSheet(
    BuildContext context,
    CalendarViewModel vm,
    DateTime? day,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemoBottomSheet(
        initialMemo: vm.getMemoFor(day),
        onSave: vm.saveMemo,
        onDelete: vm.deleteMemo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CalendarViewModel이 없을 수 있으므로 에러 핸들링
    try {
      return Consumer<CalendarViewModel>(
        builder: (context, vm, child) {
          // ViewModel이 초기화되지 않았을 경우 처리
          if (!vm.isInitialized) {
            return const SplashView(showOnlyUI: true);
          }

          // 현재 페이지 인덱스와 ViewModel의 currentMonth 동기화 (무한 루프 방지)
          final currentMonth = vm.currentMonth;
          if (_lastSyncedMonth == null ||
              (_lastSyncedMonth!.year != currentMonth.year ||
                  _lastSyncedMonth!.month != currentMonth.month)) {
            final expectedIndex = _getIndexFromMonth(currentMonth, vm.today);
            if (_pageController.hasClients) {
              final currentPage =
                  _pageController.page?.round() ?? _basePageIndex;
              if (currentPage != expectedIndex) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_pageController.hasClients && mounted) {
                    _pageController.jumpToPage(expectedIndex);
                    _lastSyncedMonth = currentMonth;
                  }
                });
              } else {
                _lastSyncedMonth = currentMonth;
              }
            }
          }

          final startSel = vm.isSelectedDayStart();
          final endSel = vm.isSelectedDayEnd();
          final selectedDay = vm.selectedDay;
          final today = vm.today;

          // 선택된 날짜가 변경되면 스크롤 위치 다시 확인
          if (_lastSelectedDay != selectedDay) {
            _lastSelectedDay = selectedDay;
            if (_scrollController.hasClients) {
              _onScroll();
            }
          }

          final isFutureDate =
              selectedDay != null &&
              DateTime(
                selectedDay.year,
                selectedDay.month,
                selectedDay.day,
              ).isAfter(DateTime(today.year, today.month, today.day));

          return Scaffold(
            backgroundColor: AppColors.surface,
            body: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  MonthHeader(
                    month: vm.currentMonth,
                    onPrev: () => _jumpToPage(-1),
                    onNext: () => _jumpToPage(1),
                    onToday: () {
                      vm.goToday(); // selectedDay도 오늘로 설정
                      if (_pageController.hasClients) {
                        final todayIndex = _getIndexFromMonth(
                          DateTime(vm.today.year, vm.today.month),
                          vm.today,
                        );
                        _pageController.jumpToPage(todayIndex);
                      }
                    },
                    onMonthSelected: (selectedMonth) {
                      vm.setCurrentMonth(selectedMonth);
                      if (_pageController.hasClients) {
                        final selectedIndex = _getIndexFromMonth(
                          selectedMonth,
                          vm.today,
                        );
                        _pageController.jumpToPage(selectedIndex);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (selectedDay != null && _showStickyHeader)
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickyWeekHeaderDelegate(
                                week: _getWeekForDate(selectedDay),
                                today: today,
                                selectedDay: selectedDay,
                                periodCycles: vm.periodCycles,
                                periodDays: vm.periodDays,
                                fertileWindowDays: vm.fertileWindowDays,
                                ovulationDay: vm.ovulationDay,
                                ovulationDays: vm.ovulationDays,
                                expectedPeriodDays: vm.expectedPeriodDays,
                                expectedFertileWindowDays:
                                    vm.expectedFertileWindowDays,
                                expectedOvulationDay: vm.expectedOvulationDay,
                                 hasRecordFor: (day) {
                                   final symptoms = vm.selectedSymptomsFor(day);
                                   return symptoms.any((s) => s != '기타/관계');
                                 },
                                 getSymptomCount: vm.getSymptomCountFor,
                                 hasMemoFor: (day) {
                                   final memo = vm.getMemoFor(day);
                                   return memo != null && memo.isNotEmpty;
                                 },
                                 hasRelationshipFor: (day) {
                                   final symptoms = vm.selectedSymptomsFor(day);
                                   return symptoms.contains('기타/관계');
                                 },
                                onSelect: vm.selectDay,
                                 isActive: widget.isActive,
                              ),
                            ),
                          // 나머지 내용
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: _getMaxCalendarHeight(),
                                    child: PageView.builder(
                                      controller: _pageController,
                                      physics: const PageScrollPhysics(),
                                      onPageChanged: (index) {
                                        final month = _getMonthFromIndex(
                                          index,
                                          vm.today,
                                        );
                                        if (vm.currentMonth.year !=
                                                month.year ||
                                            vm.currentMonth.month !=
                                                month.month) {
                                          _lastSyncedMonth = month;
                                          vm.setCurrentMonth(month);
                                        }
                                      },
                                      itemBuilder: (context, index) {
                                        final month = _getMonthFromIndex(
                                          index,
                                          vm.today,
                                        );
                                        return CalendarGrid(
                                          month: month,
                                          today: vm.today,
                                          selectedDay: vm.selectedDay,
                                          periodCycles: vm.periodCycles,
                                          periodDays: vm.periodDays,
                                          fertileWindowDays:
                                              vm.fertileWindowDays,
                                          ovulationDay: vm.ovulationDay,
                                          ovulationDays: vm.ovulationDays,
                                          expectedPeriodDays:
                                              vm.expectedPeriodDays,
                                          expectedFertileWindowDays:
                                              vm.expectedFertileWindowDays,
                                          expectedOvulationDay:
                                              vm.expectedOvulationDay,
                                           hasRecordFor: (day) {
                                             final symptoms = vm
                                                 .selectedSymptomsFor(day);
                                             return symptoms.any((s) => s != '기타/관계');
                                           },
                                           getSymptomCount:
                                               vm.getSymptomCountFor,
                                           hasMemoFor: (day) {
                                             final memo = vm.getMemoFor(day);
                                             return memo != null &&
                                                 memo.isNotEmpty;
                                           },
                                           hasRelationshipFor: (day) {
                                             final symptoms = vm
                                                 .selectedSymptomsFor(day);
                                             return symptoms.contains('기타/관계');
                                           },
                                          onSelect: vm.selectDay,
                                          isActive: widget.isActive,
                                        );
                                      },
                                    ),
                                  ),
                                  if (isFutureDate) ...[
                                    const SizedBox(height: 100),
                                    Center(
                                      child: Text(
                                        '미래 날짜입니다.',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textDisabled,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    TodayCard(
                                      selectedDay: selectedDay,
                                      today: today,
                                      periodCycles: vm.periodCycles,
                                      periodDays: vm.periodDays,
                                      expectedPeriodDays: vm.expectedPeriodDays,
                                      fertileWindowDays: vm.fertileWindowDays,
                                      expectedFertileWindowDays:
                                          vm.expectedFertileWindowDays,
                                      onPeriodStart: vm.setPeriodStart,
                                      onPeriodEnd: vm.setPeriodEnd,
                                      isStartSelected: startSel,
                                      isEndSelected: endSel,
                                      hasMemo: _hasMemo(vm, selectedDay),
                                      hasRelationship: vm
                                          .selectedSymptomsFor(selectedDay)
                                          .contains('기타/관계'),
                                      onMemoTap: () => _showMemoBottomSheet(
                                        context,
                                        vm,
                                        selectedDay,
                                      ),
                                      onRelationshipTap: () =>
                                          vm.toggleSymptom('기타/관계'),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),                                  
                                    SymptomSection(
                                      categories: vm.symptomCatalog,
                                      selectedLabels: vm.selectedSymptomsFor(
                                        selectedDay,
                                      ),
                                      onToggle: vm.toggleSymptom,
                                      hasMemo: _hasMemo(vm, selectedDay),
                                      onMemoTap: () => _showMemoBottomSheet(
                                        context,
                                        vm,
                                        selectedDay,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xl),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ),
                ],
              ),
            ),

          );
        },
      );
    } catch (e) {
      // 에러 발생 시 로그인 화면으로 이동
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('화면을 불러오는 중 오류가 발생했습니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('로그인 화면으로'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// 선택된 날짜가 포함된 주를 고정 헤더로 표시하는 Delegate
class _StickyWeekHeaderDelegate extends SliverPersistentHeaderDelegate {
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
  final bool Function(DateTime) hasRecordFor;
  final int Function(DateTime) getSymptomCount;
  final bool Function(DateTime) hasMemoFor;
  final bool Function(DateTime) hasRelationshipFor;
  final ValueChanged<DateTime> onSelect;
  final bool isActive;

  _StickyWeekHeaderDelegate({
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
    required this.hasRecordFor,
    required this.getSymptomCount,
    required this.hasMemoFor,
    required this.hasRelationshipFor,
    required this.onSelect,
    required this.isActive,
  });

  @override
  double get minExtent => 89.0;

  @override
  double get maxExtent => 89.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Container(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
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
                                : AppColors.textPrimary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: WeekRow(
              week: week,
              today: today,
              selectedDay: selectedDay,
              periodCycles: periodCycles,
              periodDays: periodDays,
              fertileWindowDays: fertileWindowDays,
              ovulationDay: ovulationDay,
              ovulationDays: ovulationDays,
              expectedPeriodDays: expectedPeriodDays,
              expectedFertileWindowDays: expectedFertileWindowDays,
              expectedOvulationDay: expectedOvulationDay,
              hasRecordFor: hasRecordFor,
              getSymptomCount: getSymptomCount,
              hasMemoFor: hasMemoFor,
              hasRelationshipFor: hasRelationshipFor,
              onSelect: onSelect,
              isActive: isActive,
            ),
          ),
          // 그라데이션 배경
          Container(
            height: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.border,
                  AppColors.border.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyWeekHeaderDelegate oldDelegate) {
    return week != oldDelegate.week ||
        selectedDay != oldDelegate.selectedDay ||
        periodDays != oldDelegate.periodDays ||
        fertileWindowDays != oldDelegate.fertileWindowDays ||
        hasRecordFor != oldDelegate.hasRecordFor ||
        hasMemoFor != oldDelegate.hasMemoFor ||
        hasRelationshipFor != oldDelegate.hasRelationshipFor ||
        isActive != oldDelegate.isActive;
  }
}
