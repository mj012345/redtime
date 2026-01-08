import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

/// 증상별 색상 정의
class SymptomColors {
  static const Color period = Color(0xFFFFEBEE); // 생리일
  static const Color fertile = Color(0xFFE8F5F6); // 가임기
  static const Color cramp = Color(0xFFFCDEC1); // 생리통
  static const Color digestion = Color(0xFFDFFDCF); // 소화
  static const Color acne = Color(0xFFFFFFFF); // 뾰루지 (기본 흰색)
  static const Color border = Color(0xFFE7E7E7); // 테두리
}

/// 증상 캘린더 히트맵 위젯
class SymptomCalendarHeatmap extends StatelessWidget {
  /// 날짜별 증상 데이터
  /// Key: 날짜 키 (yyyy-MM-dd), Value: 증상 리스트
  final Map<String, Set<String>> symptomData;

  /// 시작 날짜 (최근 30일 기준)
  final DateTime startDate;

  /// 종료 날짜 (오늘)
  final DateTime endDate;

  const SymptomCalendarHeatmap({
    super.key,
    required this.symptomData,
    required this.startDate,
    required this.endDate,
  });

  /// 날짜 포맷팅 (M/d 또는 d)
  String _formatDate(DateTime date, bool isFirstOfMonth) {
    if (isFirstOfMonth) {
      return '${date.month}/${date.day}';
    }
    return '${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    // 날짜 리스트 생성 (startDate부터 endDate까지)
    final dates = <DateTime>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    // 레이블 리스트
    const labels = ['생리일', '가임기', '생리통', '소화', '뾰루지'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 레이블 컬럼 (고정)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 공간
            const SizedBox(height: 18, width: 25),
            // 레이블들
            ...labels.map((label) {
              return SizedBox(
                height: 18,
                width: 25,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 8,
                      color: const Color(0xFF555555),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(width: 3),
        // 날짜 헤더와 그리드 (스크롤 가능, 동기화)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 헤더
                Row(
                  children: dates.map((date) {
                    final isFirstOfMonth =
                        date.day == 1 ||
                        (dates.indexOf(date) > 0 &&
                            dates[dates.indexOf(date) - 1].month != date.month);
                    return SizedBox(
                      width: 18,
                      child: Center(
                        child: Text(
                          _formatDate(date, isFirstOfMonth),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 2),
                // 날짜 그리드
                ...labels.asMap().entries.map((labelEntry) {
                  final labelIndex = labelEntry.key;
                  final label = labelEntry.value;
                  final isFirstRow = labelIndex == 0;

                  return Row(
                    children: dates.asMap().entries.map((dateEntry) {
                      final dateIndex = dateEntry.key;
                      final date = dateEntry.value;
                      final isFirstCol = dateIndex == 0;

                      // 해당 레이블의 증상이 있는지 확인
                      final dateKey =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final symptoms = symptomData[dateKey] ?? <String>{};
                      final hasSymptom = symptoms.contains(label);

                      // 레이블에 맞는 색상 적용
                      Color cellColor;
                      if (label == '생리일' && hasSymptom) {
                        cellColor = SymptomColors.period;
                      } else if (label == '가임기' && hasSymptom) {
                        cellColor = SymptomColors.fertile;
                      } else if (label == '생리통' && hasSymptom) {
                        cellColor = SymptomColors.cramp;
                      } else if (label == '소화' && hasSymptom) {
                        cellColor = SymptomColors.digestion;
                      } else if (label == '뾰루지' && hasSymptom) {
                        cellColor = SymptomColors.acne;
                      } else {
                        cellColor = Colors.white;
                      }

                      // 테두리: 오른쪽과 아래만 그리기
                      // 첫 번째 행은 위쪽, 첫 번째 열은 왼쪽, 마지막 행은 아래, 마지막 열은 오른쪽
                      return Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: cellColor,
                          border: Border(
                            right: BorderSide(
                              color: SymptomColors.border,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: SymptomColors.border,
                              width: 1,
                            ),
                            // 첫 번째 열은 왼쪽 테두리도 추가
                            left: isFirstCol
                                ? BorderSide(
                                    color: SymptomColors.border,
                                    width: 1,
                                  )
                                : BorderSide.none,
                            // 첫 번째 행은 위쪽 테두리도 추가
                            top: isFirstRow
                                ? BorderSide(
                                    color: SymptomColors.border,
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
