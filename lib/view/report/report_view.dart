import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';
import 'package:red_time_app/view/report/widgets/chart_preview.dart';
import 'package:red_time_app/view/report/widgets/summary_card.dart';
import 'package:red_time_app/view/report/widgets/symptom_stat_item.dart';

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    // 임시 더미 데이터 (추후 ViewModel 연동 예정)
    const avgCycle = 29;
    const avgPeriod = 5;
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
                  child: SummaryCard(label: '평균 생리주기', value: '$avgCycle 일'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SummaryCard(label: '평균 생리기간', value: '$avgPeriod 일'),
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
