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

/// Figma 레이아웃(채널 8usim5es)을 단일 화면으로 구현한 예시입니다.
class FigmaCalendarPage extends StatelessWidget {
  const FigmaCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    // CalendarViewModel이 없을 수 있으므로 에러 핸들링
    try {
      final vm = Provider.of<CalendarViewModel>(context, listen: true);

      // ViewModel이 초기화되지 않았을 경우 처리
      if (!vm.isInitialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          child: Container(
            color: AppColors.background,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                MonthHeader(
                  month: vm.currentMonth,
                  onPrev: vm.goPrevMonth,
                  onNext: vm.goNextMonth,
                  onToday: vm.goToday,
                ),
                const SizedBox(height: AppSpacing.md),
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
                            CalendarGrid(
                              month: vm.currentMonth,
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
                              expectedOvulationDay: vm.expectedOvulationDay,
                              symptomRecordDays: vm.symptomRecordDays,
                              onSelect: vm.selectDay,
                            ),
                            const SizedBox(height: AppSpacing.lg),
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
    } catch (e, stackTrace) {
      debugPrint('FigmaCalendarPage 빌드 에러: $e');
      debugPrint('스택: $stackTrace');
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
