import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

class ChartLinePoint {
  final String label;
  final int cycleDays;
  final int periodDays;
  final String cycleStatus; // 예: 안정적
  final String periodStatus; // 예: 정상

  const ChartLinePoint({
    required this.label,
    required this.cycleDays,
    required this.periodDays,
    required this.cycleStatus,
    required this.periodStatus,
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

    final width = data.length * 60.0 + 40;
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          // 레전드
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: [
                _legend(color: const Color(0xFFEF5568), text: '생리주기'),
                const SizedBox(width: AppSpacing.lg),
                _legend(color: const Color(0xFF55BEB5), text: '생리기간'),
              ],
            ),
          ),
          // 차트
          Positioned.fill(
            top: 26,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CustomPaint(
                size: Size(width, 200),
                painter: _LineChartPainter(
                  data: data,
                  maxValue: maxVal,
                  cycleColor: const Color(0xFFEF5568),
                  periodColor: const Color(0xFF55BEB5),
                ),
              ),
            ),
          ),
        ],
      ),
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
            fontSize: 13,
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

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.cycleColor,
    required this.periodColor,
  });

  final double topPadding = 20;
  final double bottomPadding = 36;
  final double leftPadding = 12;
  final double pointSpacing = 60;
  final double chartHeight = 140;

  @override
  void paint(Canvas canvas, Size size) {
    // 그리드 라인 (수평 4줄)
    final gridPaint = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.6)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final dy = topPadding + chartHeight * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    // 좌표 변환
    Offset _pt(int idx, int value) {
      final ratio = value / maxValue;
      final x = leftPadding + idx * pointSpacing;
      final y = topPadding + chartHeight * (1 - ratio);
      return Offset(x, y);
    }

    // 라인/포인트 그리기 함수
    void drawSeries({
      required List<Offset> points,
      required Color color,
      required List<String> statuses,
      required List<int> values,
      required bool isTop,
    }) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
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
        canvas.drawCircle(p, 4, pointPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${statuses[i]}\n${values[i]}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 60);

        final dy = isTop ? p.dy - 32 : p.dy - 14;
        final dx = p.dx - textPainter.width / 2;
        textPainter.paint(canvas, Offset(dx, dy));
      }
    }

    // 데이터 포인트
    final cyclePoints = <Offset>[];
    final periodPoints = <Offset>[];
    final cycleStatuses = <String>[];
    final periodStatuses = <String>[];
    final cycleValues = <int>[];
    final periodValues = <int>[];

    for (int i = 0; i < data.length; i++) {
      cyclePoints.add(_pt(i, data[i].cycleDays));
      periodPoints.add(_pt(i, data[i].periodDays));
      cycleStatuses.add(data[i].cycleStatus);
      periodStatuses.add(data[i].periodStatus);
      cycleValues.add(data[i].cycleDays);
      periodValues.add(data[i].periodDays);
    }

    drawSeries(
      points: cyclePoints,
      color: cycleColor,
      statuses: cycleStatuses,
      values: cycleValues,
      isTop: true,
    );

    drawSeries(
      points: periodPoints,
      color: periodColor,
      statuses: periodStatuses,
      values: periodValues,
      isTop: false,
    );

    // X축 라벨
    for (int i = 0; i < data.length; i++) {
      final p = periodPoints[i];
      final labelPainter = TextPainter(
        text: TextSpan(
          text: data[i].label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: AppColors.textPrimary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(p.dx - labelPainter.width / 2, size.height - bottomPadding + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
