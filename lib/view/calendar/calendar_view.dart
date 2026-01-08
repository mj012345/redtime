import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/calendar/calendar_viewmodel.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';
import 'widgets/month_header.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/today_card.dart';
import 'widgets/symptom_section.dart';
import 'widgets/memo_bottom_sheet.dart';

class FigmaCalendarPage extends StatefulWidget {
  const FigmaCalendarPage({super.key});

  @override
  State<FigmaCalendarPage> createState() => _FigmaCalendarPageState();
}

class _FigmaCalendarPageState extends State<FigmaCalendarPage> {
  late PageController _pageController;
  static const int _basePageIndex = 1000; // 중간 지점을 기준으로 설정
  DateTime? _lastSyncedMonth; // 마지막으로 동기화된 월 (무한 루프 방지)

  // 달력 하단 패딩 (별도 설정 가능)
  static const double _calendarBottomPadding = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _basePageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 최대 달력 높이 반환 (6주 달력 기준 - 카드 영역 고정을 위해)
  double _getMaxCalendarHeight() {
    const headerHeight = 35.0;
    const spacing = 5.0;
    const rowHeight = 51.0; // 각 주의 높이 (HorizontalLine 1px + SizedBox 50px)
    const lastLineHeight = 1.0;
    const maxRowCount = 6; // 최대 6주

    return headerHeight +
        spacing +
        (maxRowCount * rowHeight) +
        lastLineHeight +
        _calendarBottomPadding;
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

  @override
  Widget build(BuildContext context) {
    // CalendarViewModel이 없을 수 있으므로 에러 핸들링
    try {
      return Consumer<CalendarViewModel>(
        builder: (context, vm, child) {
          // ViewModel이 초기화되지 않았을 경우 처리
          if (!vm.isInitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
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

          // 선택된 날짜가 오늘 이후인지 확인 (날짜만 비교)
          final isFutureDate =
              vm.selectedDay != null &&
              DateTime(
                vm.selectedDay!.year,
                vm.selectedDay!.month,
                vm.selectedDay!.day,
              ).isAfter(DateTime(vm.today.year, vm.today.month, vm.today.day));

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  MonthHeader(
                    month: vm.currentMonth,
                    onPrev: () {
                      if (_pageController.hasClients) {
                        final currentPage =
                            _pageController.page?.round() ?? _basePageIndex;
                        _pageController.jumpToPage(currentPage - 1);
                      }
                    },
                    onNext: () {
                      if (_pageController.hasClients) {
                        final currentPage =
                            _pageController.page?.round() ?? _basePageIndex;
                        _pageController.jumpToPage(currentPage + 1);
                      }
                    },
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
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await vm.refresh();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 달력 영역만 PageView로 감싸서 좌우 스크롤 가능하게
                              // 카드 영역 고정을 위해 최대 높이(6주)로 고정
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
                                    if (vm.currentMonth.year != month.year ||
                                        vm.currentMonth.month != month.month) {
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
                                      fertileWindowDays: vm.fertileWindowDays,
                                      ovulationDay: vm.ovulationDay,
                                      ovulationDays: vm.ovulationDays,
                                      expectedPeriodDays: vm.expectedPeriodDays,
                                      expectedFertileWindowDays:
                                          vm.expectedFertileWindowDays,
                                      expectedOvulationDay:
                                          vm.expectedOvulationDay,
                                      symptomRecordDays: vm.symptomRecordDays,
                                      onSelect: vm.selectDay,
                                    );
                                  },
                                ),
                              ),
                              if (isFutureDate)
                                Center(
                                  child: Text(
                                    '미래 날짜입니다.',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textDisabled,
                                    ),
                                  ),
                                )
                              else ...[
                                TodayCard(
                                  selectedDay: vm.selectedDay,
                                  today: vm.today,
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
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  '증상',
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SymptomSection(
                                  categories: vm.symptomCatalog,
                                  selectedLabels: vm.selectedSymptomsFor(
                                    vm.selectedDay,
                                  ),
                                  onToggle: vm.toggleSymptom,
                                  hasMemo:
                                      vm.getMemoFor(vm.selectedDay) != null &&
                                      vm.getMemoFor(vm.selectedDay)!.isNotEmpty,
                                  onMemoTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => MemoBottomSheet(
                                        initialMemo: vm.getMemoFor(
                                          vm.selectedDay,
                                        ),
                                        onSave: (memo) {
                                          vm.saveMemo(memo);
                                        },
                                        onDelete: () {
                                          vm.deleteMemo();
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: BottomNav(
              current: NavTab.calendar,
              onTap: (tab) {
                if (tab == NavTab.calendar) return;
                if (tab == NavTab.report) {
                  Navigator.of(context).pushReplacementNamed('/report');
                } else if (tab == NavTab.my) {
                  Navigator.of(context).pushReplacementNamed('/my');
                }
              },
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
