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

  const ChartPreview({super.key, required this.data});

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
            cycleColor: const Color(0xFFEF5568),
            periodColor: const Color(0xFF55BEB5),
            pointSpacing: pointSpacing,
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
                    _legend(color: const Color(0xFFEF5568), text: '생리주기'),
                    const SizedBox(width: AppSpacing.lg),
                    _legend(color: const Color(0xFF55BEB5), text: '생리기간'),
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

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.cycleColor,
    required this.periodColor,
    required this.pointSpacing,
  });

  final double topPadding = 30;
  final double bottomPadding = 50;
  final double leftPadding = 12;
  final double chartHeight = 100;

  @override
  void paint(Canvas canvas, Size size) {
    // 그리드 라인 (수평 4줄)
    final gridPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final dy = topPadding + chartHeight * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    // 좌표 변환
    Offset pt(int idx, int value) {
      final ratio = value / maxValue;
      final x = leftPadding + idx * pointSpacing;
      final y = topPadding + chartHeight * (1 - ratio);
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
            style: TextStyle(color: color, fontSize: 10, height: 1.1),
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
      cyclePoints.add(pt(i, data[i].cycleDays));
      periodPoints.add(pt(i, data[i].periodDays));
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
            color: AppColors.textPrimary.withValues(alpha: 0.5),
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
