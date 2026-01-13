import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class ChartLinePoint {
  final String label;
  final int cycleDays;
  final int periodDays;

  const ChartLinePoint({
    required this.label,
    required this.cycleDays,
    required this.periodDays,
  });
}

class ChartPreview extends StatelessWidget {
  final List<ChartLinePoint> data;
  final bool isExample;

  const ChartPreview({super.key, required this.data, this.isExample = false});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxVal = data
        .map((e) => e.cycleDays > e.periodDays ? e.cycleDays : e.periodDays)
        .fold<int>(0, (p, c) => c > p ? c : p)
        .clamp(1, 999);

    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPadding = 12.0;
        final rightPadding = 12.0;
        final availableWidth =
            constraints.maxWidth - leftPadding - rightPadding;

        double pointSpacing;
        double chartWidth;
        bool enableScroll;

        if (data.length <= 6) {
          // 6개 이하: 왼쪽 정렬, 고정 간격 사용
          pointSpacing = 60.0; // 고정 간격
          chartWidth = data.length * pointSpacing + leftPadding + rightPadding;
          enableScroll = false;
        } else if (data.length < 12) {
          // 7개 이상 12개 미만: 가로 여백을 채우도록 간격 조정
          pointSpacing = availableWidth / data.length;
          chartWidth = data.length * pointSpacing + leftPadding + rightPadding;
          enableScroll = false;
        } else {
          // 12개 이상: 12개 기준 간격, 스크롤 활성화
          pointSpacing = availableWidth / 12;
          chartWidth = data.length * pointSpacing + leftPadding + rightPadding;
          enableScroll = true;
        }

        final chartWidget = CustomPaint(
          size: Size(chartWidth, 230),
          painter: _LineChartPainter(
            data: data,
            maxValue: maxVal,
            cycleColor: isExample
                ? AppColors.textDisabled
                : const Color(0xFFEF5568),
            periodColor: isExample
                ? AppColors.textDisabled.withValues(alpha: 0.7)
                : const Color(0xFF55BEB5),
            pointSpacing: pointSpacing,
            isExample: isExample,
          ),
        );

        return SizedBox(
          height: 240,
          child: Column(
            children: [
              // 레전드 (왼쪽 정렬)
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    _legend(
                      color: isExample
                          ? AppColors.textDisabled
                          : const Color(0xFFEF5568),
                      text: '생리주기',
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    _legend(
                      color: isExample
                          ? AppColors.textDisabled.withValues(alpha: 0.7)
                          : const Color(0xFF55BEB5),
                      text: '생리기간',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // 차트
              Expanded(
                child: enableScroll
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: chartWidget,
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: chartWidget,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legend({required Color color, required String text}) {
    return Row(
      children: [
        Container(width: 24, height: 2, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartLinePoint> data;
  final int maxValue;
  final Color cycleColor;
  final Color periodColor;
  final double pointSpacing;
  final bool isExample;

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.cycleColor,
    required this.periodColor,
    required this.pointSpacing,
    this.isExample = false,
  });

  final double topPadding = 30;
  final double bottomPadding = 50;
  final double leftPadding = 12;
  final double chartHeight = 100;
  static const double minLineSpacing = 35.0; // 주기와 기간 라인 사이 최소 간격 (텍스트 포함)

  @override
  void paint(Canvas canvas, Size size) {
    // 생리 기간의 최소값과 최대값 계산 (변동 폭을 더 잘 보이게 하기 위해)
    int periodMin = data.isNotEmpty ? data[0].periodDays : 1;
    int periodMax = data.isNotEmpty ? data[0].periodDays : 1;
    for (final point in data) {
      if (point.periodDays < periodMin) periodMin = point.periodDays;
      if (point.periodDays > periodMax) periodMax = point.periodDays;
    }

    // 생리 기간의 변동 폭이 너무 작으면 최소값을 조정하여 변동 폭 확대
    final periodRange = periodMax - periodMin;
    if (periodRange < 3) {
      // 변동 폭이 3 미만이면 최소값을 줄여서 변동 폭을 확대
      periodMin = (periodMin - 1).clamp(1, periodMax);
      periodMax = (periodMax + 1).clamp(periodMin, 999);
    }

    // 그리드 라인 (수평 4줄)
    final gridPaint = Paint()
      ..color = isExample
          ? AppColors.textDisabled.withValues(alpha: 0.2)
          : AppColors.primaryLight.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final dy = topPadding + chartHeight * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    // 좌표 변환 (생리주기용)
    Offset ptCycle(int idx, int value) {
      final ratio = value / maxValue;
      final x = leftPadding + idx * pointSpacing;
      final y = topPadding + chartHeight * (1 - ratio);
      return Offset(x, y);
    }

    // 좌표 변환 (생리 기간용 - 별도 스케일 사용)
    Offset ptPeriod(int idx, int value) {
      final periodRange = periodMax - periodMin;
      final effectiveRange = periodRange > 0 ? periodRange : 1;
      final ratio = (value - periodMin) / effectiveRange;
      final x = leftPadding + idx * pointSpacing;
      // 생리 기간은 그래프 하단 60% 영역을 사용하여 변동 폭을 더 크게 표시
      final periodChartHeight = chartHeight * 0.3;
      final y = topPadding + chartHeight - periodChartHeight * (1 - ratio);
      return Offset(x, y);
    }

    // 라인/포인트 그리기 함수
    void drawSeries({
      required List<Offset> points,
      required Color color,
      required List<int> values,
      required bool isTop,
    }) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int i = 0; i < points.length; i++) {
        if (i == 0) {
          path.moveTo(points[i].dx, points[i].dy);
        } else {
          path.lineTo(points[i].dx, points[i].dy);
        }
      }
      canvas.drawPath(path, linePaint);

      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        canvas.drawCircle(p, 2, pointPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${values[i]}',
            style: TextStyle(
              color: isExample ? AppColors.textDisabled : color,
              fontSize: 10,
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);

        final dy = isTop ? p.dy - 20 : p.dy - 18;
        final dx = p.dx - textPainter.width / 2;
        textPainter.paint(canvas, Offset(dx, dy));
      }
    }

    // 데이터 포인트
    final cyclePoints = <Offset>[];
    final periodPoints = <Offset>[];
    final cycleValues = <int>[];
    final periodValues = <int>[];

    for (int i = 0; i < data.length; i++) {
      var cyclePoint = ptCycle(i, data[i].cycleDays);
      var periodPoint = ptPeriod(i, data[i].periodDays);

      // 주기 텍스트 위치 (포인트 위 20픽셀)
      final cycleTextTop = cyclePoint.dy - 20;
      // 기간 텍스트 위치 (포인트 위 18픽셀)
      final periodTextTop = periodPoint.dy - 18;

      // 텍스트 높이 (fontSize 10, height 1.1 기준)
      const textHeight = 11.0;

      // 주기 텍스트 하단과 기간 텍스트 상단 사이의 거리 확인
      final cycleTextBottom = cycleTextTop + textHeight;
      final textDistance = periodTextTop - cycleTextBottom;

      // 텍스트가 겹치거나 최소 간격보다 작으면 조정
      if (textDistance < minLineSpacing) {
        // 필요한 간격 계산
        final requiredSpacing = minLineSpacing - textDistance;

        // 주기는 위로, 기간은 아래로 조정
        cyclePoint = Offset(cyclePoint.dx, cyclePoint.dy - requiredSpacing / 2);
        periodPoint = Offset(
          periodPoint.dx,
          periodPoint.dy + requiredSpacing / 2,
        );

        // 차트 영역을 벗어나지 않도록 제한
        final minCycleY = topPadding + 5;
        final maxPeriodY = topPadding + chartHeight - 5;

        if (cyclePoint.dy < minCycleY) {
          cyclePoint = Offset(cyclePoint.dx, minCycleY);
          // 기간 포인트도 다시 조정 (텍스트 간격 유지)
          // 주기 텍스트 하단: minCycleY - 20 + textHeight
          // 기간 텍스트 상단: periodPoint.dy - 18
          // 간격: (periodPoint.dy - 18) - (minCycleY - 20 + textHeight) >= minLineSpacing
          final minPeriodY = minCycleY - 20 + textHeight + minLineSpacing + 18;
          periodPoint = Offset(periodPoint.dx, minPeriodY);
        }

        if (periodPoint.dy > maxPeriodY) {
          periodPoint = Offset(periodPoint.dx, maxPeriodY);
          // 주기 포인트도 다시 조정 (텍스트 간격 유지)
          // 기간 텍스트 상단: maxPeriodY - 18
          // 주기 텍스트 하단: cyclePoint.dy - 20 + textHeight
          // 간격: (maxPeriodY - 18) - (cyclePoint.dy - 20 + textHeight) >= minLineSpacing
          final maxCycleY = maxPeriodY - 18 - minLineSpacing - textHeight + 20;
          if (maxCycleY >= minCycleY) {
            cyclePoint = Offset(cyclePoint.dx, maxCycleY);
          }
        }
      }

      cyclePoints.add(cyclePoint);
      periodPoints.add(periodPoint);
      cycleValues.add(data[i].cycleDays);
      periodValues.add(data[i].periodDays);
    }

    drawSeries(
      points: cyclePoints,
      color: cycleColor,
      values: cycleValues,
      isTop: true,
    );

    drawSeries(
      points: periodPoints,
      color: periodColor,
      values: periodValues,
      isTop: false,
    );

    // X축 라벨 (가장 아래 그리드 라인 바로 아래에 배치, 카드 영역 안쪽에 위치)
    final bottomGridLineY = topPadding + chartHeight;
    // X축 라벨이 카드 영역을 벗어나지 않도록 하단 여백 확보
    final minBottomMargin = 10.0; // 하단 여백
    final maxLabelY = size.height - minBottomMargin;

    for (int i = 0; i < data.length; i++) {
      final p = periodPoints[i];
      final labelPainter = TextPainter(
        text: TextSpan(
          text: data[i].label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: isExample
                ? AppColors.textDisabled.withValues(alpha: 0.5)
                : AppColors.textPrimary.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // 가장 하단 그리드 라인 바로 아래에 배치 (그리드 라인 밖으로)
      // 그리드 라인 아래 최소 간격을 두고 배치
      final labelSpacing = 8.0; // 그리드 라인과의 간격
      // 라벨의 상단이 그리드 라인 아래에 오도록 보장
      final minLabelY = bottomGridLineY + labelSpacing;

      // 라벨이 카드 영역 안쪽에 위치하도록 확인
      final labelBottom = minLabelY + labelPainter.height;
      final finalLabelY = labelBottom > maxLabelY
          ? maxLabelY - labelPainter.height
          : minLabelY;

      // 최종 라벨 위치가 그리드 라인 아래에 있는지 확인
      final safeLabelY = finalLabelY < bottomGridLineY
          ? bottomGridLineY + labelSpacing
          : finalLabelY;

      labelPainter.paint(
        canvas,
        Offset(p.dx - labelPainter.width / 2, safeLabelY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
