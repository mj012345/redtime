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
      return (avgCycle: '- 일', avgPeriod: '- 일');
    }

    // 최근 6개월 전 날짜 계산 (월 계산 시 음수 처리)
    int targetYear = today.year;
    int targetMonth = today.month - 6;

    // 월이 음수가 되면 이전 해로 조정
    while (targetMonth <= 0) {
      targetMonth += 12;
      targetYear -= 1;
    }

    final sixMonthsAgoDate = DateTime(targetYear, targetMonth, 1);

    // 최근 6개월 내의 주기만 필터링 (시간 부분 제거하여 비교)
    final recentCycles = periodCycles.where((cycle) {
      final cycleStart = DateTime(
        cycle.start.year,
        cycle.start.month,
        cycle.start.day,
      );
      return !cycleStart.isBefore(sixMonthsAgoDate);
    }).toList();

    if (recentCycles.isEmpty) {
      return (avgCycle: '- 일', avgPeriod: '- 일');
    }

    // 주기 정렬
    final sorted = [...recentCycles]
      ..sort((a, b) => a.start.compareTo(b.start));

    // 주기 간격 계산 (각 주기 시작일 사이의 일 수)
    final intervals = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].start.difference(sorted[i - 1].start).inDays;
      if (diff > 0) {
        intervals.add(diff);
      }
    }

    // 평균 주기 길이 계산 (간격의 평균)
    String avgCycle;
    if (intervals.isNotEmpty) {
      final sum = intervals.reduce((a, b) => a + b);
      final avg = (sum / intervals.length).round();
      avgCycle = '$avg 일';
    } else {
      avgCycle = '- 일';
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

  /// 최근 12개월 기준으로 자주 기록된 증상 통계 계산
  List<SymptomStatItemData> _calculateSymptomStats(
    Map<String, Set<String>> symptomSelections,
    DateTime today,
  ) {
    // 최근 12개월 전 날짜 계산
    int targetYear = today.year;
    int targetMonth = today.month - 12;

    // 월이 음수가 되면 이전 해로 조정
    while (targetMonth <= 0) {
      targetMonth += 12;
      targetYear -= 1;
    }

    final twelveMonthsAgoDate = DateTime(targetYear, targetMonth, 1);

    // 최근 12개월 내의 증상 데이터만 필터링
    final recentSymptoms = <String, Set<String>>{};
    for (final entry in symptomSelections.entries) {
      final dateKey = entry.key;
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        try {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          if (!date.isBefore(twelveMonthsAgoDate)) {
            recentSymptoms[dateKey] = entry.value;
          }
        } catch (e) {
          // 날짜 파싱 실패 시 무시
        }
      }
    }

    if (recentSymptoms.isEmpty) {
      return [];
    }

    // 각 증상별 기록 횟수 계산
    final symptomCounts = <String, int>{};
    int totalRecordedDays = 0;

    for (final symptoms in recentSymptoms.values) {
      if (symptoms.isNotEmpty) {
        totalRecordedDays++;
      }
      for (final symptom in symptoms) {
        symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
      }
    }

    if (symptomCounts.isEmpty || totalRecordedDays == 0) {
      return [];
    }

    // 기록 횟수 기준으로 정렬 (내림차순)
    final sortedSymptoms = symptomCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 상위 3개만 선택
    final topSymptoms = sortedSymptoms.take(3).toList();

    // 색상 정의 (기존 색상 사용)
    final colors = [
      AppColors.primary,
      const Color(0xFFFE7A36),
      const Color(0xFF84A9B6),
    ];

    // SymptomStatItemData 리스트 생성
    final result = <SymptomStatItemData>[];
    for (int i = 0; i < topSymptoms.length; i++) {
      final entry = topSymptoms[i];
      final count = entry.value;
      final ratio = totalRecordedDays > 0 ? count / totalRecordedDays : 0.0;

      result.add(
        SymptomStatItemData(
          label: entry.key,
          count: count,
          ratio: ratio.clamp(0.0, 1.0),
          color: colors[i % colors.length],
        ),
      );
    }

    return result;
  }

  /// 실제 생리 주기 데이터를 기반으로 차트 데이터 생성
  List<ChartLinePoint> _generateChartData(List<PeriodCycle> periodCycles) {
    if (periodCycles.isEmpty) {
      return [];
    }

    // 날짜순으로 정렬
    final sorted = [...periodCycles]
      ..sort((a, b) => a.start.compareTo(b.start));

    final chartData = <ChartLinePoint>[];

    for (int i = 0; i < sorted.length; i++) {
      final cycle = sorted[i];

      // 라벨: 시작일을 "M.d" 형식으로 (예: "9.20")
      final label = '${cycle.start.month}.${cycle.start.day}';

      // 주기 간격 계산 (이전 주기와의 시작일 차이)
      int cycleDays;
      if (i == 0) {
        // 첫 번째 주기는 다음 주기와의 간격을 사용
        if (sorted.length > 1) {
          final diff = sorted[1].start.difference(cycle.start).inDays;
          cycleDays = diff > 0 ? diff : 28; // 기본값 28일
        } else {
          cycleDays = 28; // 주기가 하나만 있으면 기본값 28일
        }
      } else {
        final diff = cycle.start.difference(sorted[i - 1].start).inDays;
        cycleDays = diff > 0 ? diff : 28; // 기본값 28일
      }

      // 생리 기간 계산 (시작일부터 종료일까지의 일 수)
      int periodDays;
      if (cycle.end != null) {
        final duration = cycle.end!.difference(cycle.start).inDays + 1;
        periodDays = duration > 0 ? duration : 1;
      } else {
        // 종료일이 없으면 1일로 설정
        periodDays = 1;
      }

      chartData.add(
        ChartLinePoint(
          label: label,
          cycleDays: cycleDays,
          periodDays: periodDays,
        ),
      );
    }

    return chartData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('리포트', style: AppTextStyles.title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer<CalendarViewModel>(
        builder: (context, vm, child) {
          final averages = _calculateAverages(vm.periodCycles, vm.today);
          final avgCycle = averages.avgCycle;
          final avgPeriod = averages.avgPeriod;

          // 증상 데이터 확인
          final symptomSelections = vm.symptomSelections;

          final symptomStats = _calculateSymptomStats(
            symptomSelections,
            vm.today,
          );
          final chartData = _generateChartData(vm.periodCycles);

          return RefreshIndicator(
            onRefresh: () async {
              await vm.refresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 평균 생리주기, 평균 생리기간
                  Text(
                    "최근 6개월 기준",
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

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
                  // 2. 자주 기록된 증상
                  Text(
                    "최근 12개월 기준",
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

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
                            fontSize: AppTextStyles.title.fontSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (symptomStats.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Center(
                              child: Text(
                                '증상 기록이 없습니다.',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textDisabled,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final item in symptomStats) ...[
                            SymptomStatItem(data: item),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // 3. 주기 변동 그래프
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
                          '주기 변동 그래프',
                          style: AppTextStyles.body.copyWith(
                            fontSize: AppTextStyles.title.fontSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          height: 220,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: ChartPreview(data: chartData),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
