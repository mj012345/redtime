import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';
import 'package:red_time_app/view/report/widgets/chart_preview.dart';
import 'package:red_time_app/view/report/widgets/summary_card.dart';
import 'package:red_time_app/view/report/widgets/symptom_stat_item.dart';
import 'package:red_time_app/view/report/widgets/symptom_calendar_heatmap.dart';
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

    // 각 증상별 기록 횟수 계산 ('좋음' 제외)
    final symptomCounts = <String, int>{};
    int totalRecordedDays = 0;

    for (final symptoms in recentSymptoms.values) {
      if (symptoms.isNotEmpty) {
        totalRecordedDays++;
      }
      for (final symptom in symptoms) {
        // '좋음'은 카운트에서 제외
        if (symptom.endsWith('/좋음') || symptom == '좋음') {
          continue;
        }
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

      // "카테고리/증상" 형식에서 증상 이름만 추출 (카테고리 이름 제거)
      String symptomLabel = entry.key;
      // 카테고리 이름에 슬래시가 포함될 수 있으므로 마지막 슬래시를 기준으로 분리
      final lastSlashIndex = symptomLabel.lastIndexOf('/');
      if (lastSlashIndex != -1) {
        symptomLabel = symptomLabel.substring(lastSlashIndex + 1); // 증상 이름만 사용
      }

      result.add(
        SymptomStatItemData(
          label: symptomLabel,
          count: count,
          ratio: ratio.clamp(0.0, 1.0),
          color: colors[i % colors.length],
        ),
      );
    }

    return result;
  }

  /// 실제 생리 주기 데이터를 기반으로 차트 데이터 생성
  List<ChartLinePoint> _generateChartData(
    List<PeriodCycle> periodCycles,
    DateTime today,
  ) {
    if (periodCycles.isEmpty) {
      return [];
    }

    // 시작 날짜 계산: 오늘이 1월이면 작년 1월 1일부터, 그 외에는 1년 전 오늘부터
    final startDate = today.month == 1
        ? DateTime(today.year - 1, 1, 1)
        : DateTime(today.year - 1, today.month, today.day);

    // 최근 1년치 데이터만 필터링 (작년 1월 1일부터 또는 1년 전 오늘부터)
    final recentCycles = periodCycles.where((cycle) {
      final cycleStart = DateTime(
        cycle.start.year,
        cycle.start.month,
        cycle.start.day,
      );
      return !cycleStart.isBefore(startDate);
    }).toList();

    if (recentCycles.isEmpty) {
      return [];
    }

    // 날짜순으로 정렬
    final sorted = [...recentCycles]
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

  /// 예시 증상 데이터 생성 (회색 표시용)
  Map<String, Set<String>> _generateExampleSymptomData(DateTime today) {
    final exampleData = <String, Set<String>>{};
    // 최근 40일 중 다양한 날짜에 예시 증상 추가
    for (int i = 0; i < 40; i++) {
      final date = today.subtract(Duration(days: 39 - i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final symptoms = <String>{};

      // 다양한 카테고리의 증상 추가 (여러 증상을 같은 날짜에 기록할 수 있음)
      if (i % 3 == 0 || i % 7 == 0) {
        symptoms.add('통증/두통');
      }
      if (i % 5 == 0) {
        symptoms.add('통증/생리통');
      }
      if (i % 4 == 0) {
        symptoms.add('소화/변비');
      }
      if (i % 6 == 0) {
        symptoms.add('컨디션/욕구/피로');
      }
      if (i % 8 == 0) {
        symptoms.add('피부/뾰루지');
      }
      if (i % 9 == 0) {
        symptoms.add('기분/짜증');
      }
      if (i % 10 == 0) {
        symptoms.add('질상태/질분비물');
      }
      // 추가 증상들
      if (i % 11 == 0) {
        symptoms.add('통증/허리');
      }
      if (i % 12 == 0) {
        symptoms.add('소화/설사');
      }
      if (i % 13 == 0) {
        symptoms.add('컨디션/욕구/불면증');
      }
      if (i % 14 == 0) {
        symptoms.add('피부/피부건조');
      }
      if (i % 15 == 0) {
        symptoms.add('기분/불안');
      }
      if (i % 16 == 0) {
        symptoms.add('질상태/질건조');
      }

      if (symptoms.isNotEmpty) {
        exampleData[dateKey] = symptoms;
      }
    }
    return exampleData;
  }

  /// 예시 생리일 데이터 생성
  List<DateTime> _generateExamplePeriodDays(DateTime today) {
    final periodDays = <DateTime>[];
    // 예시: 최근 40일 중 2주기 정도의 생리일 추가
    for (int i = 0; i < 40; i++) {
      final date = today.subtract(Duration(days: 39 - i));
      // 첫 번째 주기: 5일간
      if (i >= 10 && i < 15) {
        periodDays.add(date);
      }
      // 두 번째 주기: 5일간
      if (i >= 30 && i < 35) {
        periodDays.add(date);
      }
    }
    return periodDays;
  }

  /// 예시 가임기 데이터 생성
  List<DateTime> _generateExampleFertileDays(DateTime today) {
    final fertileDays = <DateTime>[];
    // 예시: 생리일 이후 약 10일 후부터 5일간 가임기
    for (int i = 0; i < 40; i++) {
      final date = today.subtract(Duration(days: 39 - i));
      // 첫 번째 가임기: 생리일 이후
      if (i >= 20 && i < 25) {
        fertileDays.add(date);
      }
      // 두 번째 가임기
      if (i >= 5 && i < 10) {
        fertileDays.add(date);
      }
    }
    return fertileDays;
  }

  /// 예시 차트 데이터 생성 (회색 표시용)
  List<ChartLinePoint> _generateExampleChartData() {
    return [
      const ChartLinePoint(label: '1.1', cycleDays: 28, periodDays: 5),
      const ChartLinePoint(label: '1.29', cycleDays: 30, periodDays: 6),
      const ChartLinePoint(label: '2.28', cycleDays: 28, periodDays: 5),
      const ChartLinePoint(label: '3.28', cycleDays: 29, periodDays: 5),
      const ChartLinePoint(label: '4.26', cycleDays: 30, periodDays: 6),
      const ChartLinePoint(label: '5.26', cycleDays: 28, periodDays: 5),
    ];
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
          final chartData = _generateChartData(vm.periodCycles, vm.today);

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
                          Stack(
                            children: [
                              // 예시 데이터 (회색)
                              Column(
                                children: [
                                  for (final item in [
                                    SymptomStatItemData(
                                      label: '두통',
                                      count: 12,
                                      ratio: 0.6,
                                      color: AppColors.textDisabled,
                                    ),
                                    SymptomStatItemData(
                                      label: '생리통',
                                      count: 8,
                                      ratio: 0.4,
                                      color: AppColors.textDisabled,
                                    ),
                                    SymptomStatItemData(
                                      label: '피로',
                                      count: 5,
                                      ratio: 0.25,
                                      color: AppColors.textDisabled,
                                    ),
                                  ]) ...[
                                    SymptomStatItem(data: item),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                ],
                              ),
                              // 레이어 문구 (반투명)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            '아직 등록된 증상이 없어요.',
                                            style: AppTextStyles.body.copyWith(
                                              fontSize: 14,
                                              color: AppColors.primary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                  // 주기/증상 트래킹
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
                          '주기/증상 트래킹',
                          style: AppTextStyles.body.copyWith(
                            fontSize: AppTextStyles.title.fontSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // 데이터 확인: 증상 데이터나 주기 데이터가 있는지 확인
                        Builder(
                          builder: (context) {
                            final hasData =
                                symptomSelections.isNotEmpty ||
                                vm.periodDays.isNotEmpty ||
                                vm.fertileWindowDays.isNotEmpty;

                            return Stack(
                              children: [
                                // 증상 캘린더 히트맵
                                SymptomCalendarHeatmap(
                                  symptomData: hasData
                                      ? symptomSelections
                                      : _generateExampleSymptomData(vm.today),
                                  periodDays: hasData
                                      ? vm.periodDays
                                      : _generateExamplePeriodDays(vm.today),
                                  fertileWindowDays: hasData
                                      ? vm.fertileWindowDays
                                      : _generateExampleFertileDays(vm.today),
                                  symptomCatalog: vm.symptomCatalog,
                                  memos: hasData ? vm.memos : {},
                                  startDate: DateTime(
                                    vm.today.year - 1,
                                    vm.today.month,
                                    vm.today.day,
                                  ),
                                  endDate: DateTime(
                                    vm.today.year,
                                    vm.today.month,
                                    vm.today.day,
                                  ),
                                  isExample: !hasData,
                                ),
                                // 레이어 문구 (반투명)
                                if (!hasData)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(
                                            AppSpacing.md,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppSpacing.radiusMd,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 20,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.sm,
                                              ),
                                              Text(
                                                '아직 등록된 증상이 없어요.',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                      fontSize: 14,
                                                      color: AppColors.primary,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
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
                        if (chartData.isEmpty)
                          Stack(
                            children: [
                              // 예시 차트 데이터 (회색)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                                child: ChartPreview(
                                  data: _generateExampleChartData(),
                                  isExample: true,
                                ),
                              ),
                              // 레이어 문구 (반투명)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          Text(
                                            '아직 등록된 주기가 없어요.',
                                            style: AppTextStyles.body.copyWith(
                                              fontSize: 14,
                                              color: AppColors.primary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
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
