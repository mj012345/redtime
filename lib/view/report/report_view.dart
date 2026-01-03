import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';
import 'package:red_time_app/view/report/widgets/chart_preview.dart';
import 'package:red_time_app/view/report/widgets/summary_card.dart';
import 'package:red_time_app/view/report/widgets/symptom_stat_item.dart';
import 'package:red_time_app/view/calendar/calendar_viewmodel.dart';
import 'package:red_time_app/models/period_cycle.dart';

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  /// 최근 6개월 데이터 기준으로 평균 주기와 평균 기간 계산
  ({String avgCycle, String avgPeriod}) _calculateAverages(
    List<PeriodCycle> periodCycles,
    DateTime today,
  ) {
    if (periodCycles.isEmpty) {
      print('📊 [ReportView] 주기 데이터 없음');
      return (avgCycle: '- 일', avgPeriod: '- 일');
    }

    // 최근 6개월 전 날짜 계산 (월 계산 시 음수 처리)
    final todayDate = DateTime(today.year, today.month, today.day);
    int targetYear = today.year;
    int targetMonth = today.month - 6;

    // 월이 음수가 되면 이전 해로 조정
    while (targetMonth <= 0) {
      targetMonth += 12;
      targetYear -= 1;
    }

    final sixMonthsAgoDate = DateTime(targetYear, targetMonth, 1);
    print('📊 [ReportView] 전체 주기 개수: ${periodCycles.length}');
    print('📊 [ReportView] 오늘 날짜: $todayDate');
    print('📊 [ReportView] 최근 6개월 기준일: $sixMonthsAgoDate');

    // 최근 6개월 내의 주기만 필터링 (시간 부분 제거하여 비교)
    final recentCycles = periodCycles.where((cycle) {
      final cycleStart = DateTime(
        cycle.start.year,
        cycle.start.month,
        cycle.start.day,
      );
      return !cycleStart.isBefore(sixMonthsAgoDate);
    }).toList();

    print('📊 [ReportView] 최근 6개월 내 주기 개수: ${recentCycles.length}');

    if (recentCycles.isEmpty) {
      print('📊 [ReportView] 최근 6개월 데이터 없음');
      return (avgCycle: '- 일', avgPeriod: '- 일');
    }

    // 주기 정렬
    final sorted = [...recentCycles]
      ..sort((a, b) => a.start.compareTo(b.start));

    print('📊 [ReportView] 정렬된 주기:');
    for (final cycle in sorted) {
      print('  - 시작: ${cycle.start}, 종료: ${cycle.end}');
    }

    // 주기 간격 계산 (각 주기 시작일 사이의 일 수)
    final intervals = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].start.difference(sorted[i - 1].start).inDays;
      if (diff > 0) {
        intervals.add(diff);
        print(
          '📊 [ReportView] 주기 간격: ${sorted[i - 1].start} ~ ${sorted[i].start} = $diff 일',
        );
      }
    }

    print('📊 [ReportView] 주기 간격 개수: ${intervals.length}');

    // 평균 주기 길이 계산 (간격의 평균)
    String avgCycle;
    if (intervals.isNotEmpty) {
      final sum = intervals.reduce((a, b) => a + b);
      final avg = (sum / intervals.length).round();
      avgCycle = '$avg 일';
      print('📊 [ReportView] 평균 주기 계산: $sum / ${intervals.length} = $avg 일');
    } else {
      avgCycle = '- 일';
      print('📊 [ReportView] 주기 간격이 없어 평균 주기 계산 불가 (주기 1개만 있음)');
    }

    // 생리 기간 계산 (각 주기의 시작일과 종료일 차이)
    final durations = <int>[];
    for (final cycle in sorted) {
      final end = cycle.end ?? cycle.start;
      final duration = end.difference(cycle.start).inDays + 1;
      if (duration > 0) durations.add(duration);
    }

    // 평균 생리 기간 계산 (주기 2개 미만이면 계산 불가)
    String avgPeriod;
    if (sorted.length >= 2 && durations.isNotEmpty) {
      final sum = durations.reduce((a, b) => a + b);
      final avg = (sum / durations.length).round();
      avgPeriod = '$avg 일';
    } else {
      avgPeriod = '- 일';
    }

    return (avgCycle: avgCycle, avgPeriod: avgPeriod);
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<CalendarViewModel>(context, listen: false);
    final averages = _calculateAverages(vm.periodCycles, vm.today);
    final avgCycle = averages.avgCycle;
    final avgPeriod = averages.avgPeriod;
    final symptomStats = const [
      SymptomStatItemData(
        label: '생리통',
        count: 12,
        ratio: 0.97,
        color: AppColors.primary,
      ),
      SymptomStatItemData(
        label: '생리통',
        count: 8,
        ratio: 0.66,
        color: Color(0xFFFE7A36),
      ),
      SymptomStatItemData(
        label: '생리통',
        count: 5,
        ratio: 0.42,
        color: Color(0xFF84A9B6),
      ),
    ];
    final chartData = const [
      ChartLinePoint(
        label: '9.20',
        cycleDays: 32,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '3.17',
        cycleDays: 25,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '4.9',
        cycleDays: 23,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '5.6',
        cycleDays: 27,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '5.31',
        cycleDays: 25,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '6.28',
        cycleDays: 28,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '7.24',
        cycleDays: 26,
        periodDays: 5,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '8.24',
        cycleDays: 31,
        periodDays: 4,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '9.22',
        cycleDays: 29,
        periodDays: 4,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '10.15',
        cycleDays: 23,
        periodDays: 3,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '11.10',
        cycleDays: 26,
        periodDays: 6,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
      ChartLinePoint(
        label: '12.12',
        cycleDays: 32,
        periodDays: 3,
        cycleStatus: '안정적',
        periodStatus: '정상',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('리포트', style: AppTextStyles.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SummaryCard(label: '평균 생리주기', value: avgCycle),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SummaryCard(label: '평균 생리기간', value: avgPeriod),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최근 주기 추이',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.primaryLight),
                    ),
                    child: ChartPreview(data: chartData),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자주 기록된 증상',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final item in symptomStats) ...[
                    SymptomStatItem(data: item),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        current: NavTab.report,
        onTap: (tab) {
          if (tab == NavTab.report) return;
          if (tab == NavTab.calendar) {
            Navigator.of(context).pushReplacementNamed('/calendar');
          } else {
            Navigator.of(context).pushReplacementNamed('/my');
          }
        },
      ),
    );
  }
}
