import 'package:flutter/material.dart';
import 'package:red_time_app/models/symptom_category.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

/// 증상별 색상 정의
class SymptomColors {
  static const Color period = Color(0xFFFFEBEE); // 생리일
  static const Color fertile = Color(0xFFE8F5F6); // 가임기
  static const Color border = Color(0xFFE7E7E7); // 테두리
  static const Color symptomBase = Color(0xFFFFC477); // 증상 기본 색상
  static const Color goodSymptom = Color(0xFFACEEBB); // 좋음 증상 색상
}

/// 카테고리별 레이블 정보
class _CategoryLabel {
  final String categoryTitle;
  final List<String> symptoms;
  final bool hasGood;
  final List<String> otherSymptoms;

  _CategoryLabel({required this.categoryTitle, required this.symptoms})
    : hasGood = symptoms.contains('좋음'),
      otherSymptoms = symptoms.where((s) => s != '좋음').toList();
}

/// 증상 캘린더 히트맵 위젯
class SymptomCalendarHeatmap extends StatefulWidget {
  /// 날짜별 증상 데이터
  /// Key: 날짜 키 (yyyy-MM-dd), Value: 증상 리스트
  final Map<String, Set<String>> symptomData;

  /// 생리일 리스트
  final List<DateTime> periodDays;

  /// 가임기 리스트
  final List<DateTime> fertileWindowDays;

  /// 증상 카테고리 리스트
  final List<SymptomCategory> symptomCatalog;

  /// 시작 날짜 (최근 40일 기준)
  final DateTime startDate;

  /// 종료 날짜 (오늘)
  final DateTime endDate;

  const SymptomCalendarHeatmap({
    super.key,
    required this.symptomData,
    required this.periodDays,
    required this.fertileWindowDays,
    required this.symptomCatalog,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<SymptomCalendarHeatmap> createState() => _SymptomCalendarHeatmapState();
}

class _SymptomCalendarHeatmapState extends State<SymptomCalendarHeatmap> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 날짜 포맷팅 (M.d 또는 d)
  String _formatDate(DateTime date, bool isFirstOfMonth) {
    if (isFirstOfMonth) {
      return '${date.month}.${date.day}';
    }
    return '${date.day}';
  }

  /// 증상 이름으로 카테고리 찾기 (카테고리/증상 형식 지원)
  String? _findCategoryForSymptom(String symptom) {
    // "카테고리/증상" 형식인 경우 파싱
    if (symptom.contains('/')) {
      final parts = symptom.split('/');
      if (parts.length == 2) {
        return parts[0]; // 카테고리 반환
      }
    }

    // 기존 형식 지원 (하위 호환성)
    for (final category in widget.symptomCatalog) {
      for (final group in category.groups) {
        if (group.contains(symptom)) {
          return category.title;
        }
      }
    }
    return null;
  }

  /// 증상 이름 추출 (카테고리/증상 형식에서 증상만)
  String _extractSymptomName(String symptom) {
    if (symptom.contains('/')) {
      final parts = symptom.split('/');
      if (parts.length == 2) {
        return parts[1]; // 증상 이름만 반환
      }
    }
    return symptom;
  }

  /// 카테고리 이름으로 증상 리스트 가져오기
  List<String> _getSymptomsForCategory(String categoryTitle) {
    final categoryLabels = _generateCategoryLabels();
    for (final categoryLabel in categoryLabels) {
      if (categoryLabel.categoryTitle == categoryTitle) {
        return categoryLabel.symptoms;
      }
    }
    return [];
  }

  /// 카테고리별 레이블 리스트 생성
  List<_CategoryLabel> _generateCategoryLabels() {
    // 최근 40일 데이터 기준으로 증상 기록 횟수 계산
    final symptomCounts = <String, int>{};
    final excludedSymptoms = {'생리일', '가임기', '메모'};

    for (final entry in widget.symptomData.entries) {
      final dateKey = entry.key;
      final symptoms = entry.value;

      // 날짜가 startDate와 endDate 사이인지 확인
      try {
        final parts = dateKey.split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          if (!date.isBefore(widget.startDate) &&
              !date.isAfter(widget.endDate)) {
            for (final symptom in symptoms) {
              if (!excludedSymptoms.contains(symptom)) {
                symptomCounts[symptom] = (symptomCounts[symptom] ?? 0) + 1;
              }
            }
          }
        }
      } catch (e) {
        // 날짜 파싱 실패 시 무시
      }
    }

    // 카테고리별로 증상 그룹화
    final categoryMap = <String, Map<String, int>>{}; // 증상 이름 -> 카운트 매핑
    for (final symptom in symptomCounts.keys) {
      final category = _findCategoryForSymptom(symptom);
      if (category != null) {
        final symptomName = _extractSymptomName(symptom);
        final count = symptomCounts[symptom] ?? 0;
        categoryMap.putIfAbsent(category, () => <String, int>{})[symptomName] =
            (categoryMap[category]![symptomName] ?? 0) + count;
      }
    }

    // 카테고리별 레이블 생성
    final categoryLabels = <_CategoryLabel>[];
    for (final entry in categoryMap.entries) {
      // 기록 횟수 기준으로 정렬
      final sortedSymptoms = entry.value.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      categoryLabels.add(
        _CategoryLabel(
          categoryTitle: entry.key,
          symptoms: sortedSymptoms.map((e) => e.key).toList(),
        ),
      );
    }

    // 카테고리 이름 순으로 정렬
    categoryLabels.sort((a, b) => a.categoryTitle.compareTo(b.categoryTitle));

    return categoryLabels;
  }

  /// 모든 레이블 행 생성 (카테고리만)
  List<_LabelRow> _generateLabelRows() {
    final rows = <_LabelRow>[];

    // 고정 레이블
    rows.add(_LabelRow(label: '생리일', isCategory: false));
    rows.add(_LabelRow(label: '가임기', isCategory: false));

    // 카테고리별 레이블
    final categoryLabels = _generateCategoryLabels();
    for (final categoryLabel in categoryLabels) {
      // 카테고리 행만 추가
      rows.add(
        _LabelRow(
          label: categoryLabel.categoryTitle,
          isCategory: true,
          categoryTitle: categoryLabel.categoryTitle,
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    // 날짜 리스트 생성 (startDate부터 endDate까지)
    final dates = <DateTime>[];
    var current = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
    final end = DateTime(
      widget.endDate.year,
      widget.endDate.month,
      widget.endDate.day,
    );

    while (!current.isAfter(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    // 레이블 행 리스트
    final labelRows = _generateLabelRows();

    // 빌드 완료 후 오른쪽 끝으로 스크롤
    if (!_hasScrolledToEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && !_hasScrolledToEnd) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          _hasScrolledToEnd = true;
        }
      });
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 레이블 컬럼 (고정)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 공간 (셀 높이 20 + 하단 간격 6 = 26)
            const SizedBox(height: 26, width: 60),
            // 레이블들 (셀 높이 20 + 하단 간격 6 = 26)
            ...labelRows.map((labelRow) {
              return SizedBox(
                height: 26,
                width: 60,
                child: Transform.translate(
                  offset: const Offset(0, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      labelRow.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: const Color(0xFF555555),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        // 날짜 헤더와 그리드 (스크롤 가능, 동기화)
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 헤더 (셀 높이 20 + 하단 간격 6 = 26)
                SizedBox(
                  height: 26,
                  child: Row(
                    children: dates.asMap().entries.map((entry) {
                      final index = entry.key;
                      final date = entry.value;
                      final isFirstOfMonth =
                          index == 0 ||
                          date.day == 1 ||
                          (index > 0 && dates[index - 1].month != date.month);

                      // 오늘 날짜인지 확인
                      final today = DateTime.now();
                      final isToday =
                          date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;

                      // 월의 1일인지 확인
                      final isFirstDay = date.day == 1;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 20,
                          child: Center(
                            child: Text(
                              _formatDate(date, isFirstOfMonth),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                color: isToday
                                    ? AppColors.primary
                                    : AppColors.textPrimary.withValues(
                                        alpha: isFirstDay ? 0.8 : 0.5,
                                      ),
                                fontWeight: isToday || isFirstDay
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // 날짜 그리드
                ...labelRows.asMap().entries.map((labelEntry) {
                  final labelRow = labelEntry.value;

                  return Row(
                    children: dates.asMap().entries.map((dateEntry) {
                      final date = dateEntry.value;

                      // 해당 레이블의 증상이 있는지 확인
                      final dateKey =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final symptoms =
                          widget.symptomData[dateKey] ?? <String>{};

                      bool hasSymptom = false;
                      Color cellColor = AppColors.disabled;

                      // 생리일과 가임기는 별도 처리
                      if (labelRow.label == '생리일') {
                        hasSymptom = widget.periodDays.any(
                          (d) =>
                              d.year == date.year &&
                              d.month == date.month &&
                              d.day == date.day,
                        );
                        if (hasSymptom) {
                          cellColor = SymptomColors.period;
                        }
                      } else if (labelRow.label == '가임기') {
                        hasSymptom = widget.fertileWindowDays.any(
                          (d) =>
                              d.year == date.year &&
                              d.month == date.month &&
                              d.day == date.day,
                        );
                        if (hasSymptom) {
                          cellColor = SymptomColors.fertile;
                        }
                      } else if (labelRow.isCategory) {
                        // 카테고리 행: 해당 카테고리의 증상 개수 확인
                        final categorySymptoms = _getSymptomsForCategory(
                          labelRow.label,
                        );
                        // "좋음" 증상이 있는지 확인
                        final hasGood = symptoms.contains(
                          '${labelRow.label}/좋음',
                        );
                        if (hasGood) {
                          // '좋음'이 있으면 항상 62AD9E 색상, 투명도 100%
                          cellColor = SymptomColors.goodSymptom;
                          hasSymptom = true;
                        } else {
                          // "카테고리/증상" 형식으로 해당 카테고리의 증상 개수 세기
                          final symptomCount = categorySymptoms
                              .where(
                                (symptom) => symptoms.contains(
                                  '${labelRow.label}/$symptom',
                                ),
                              )
                              .length;
                          if (symptomCount > 0) {
                            // 증상 개수에 따라 투명도 적용
                            double alpha = 1.0;
                            if (symptomCount == 1) {
                              alpha = 0.3;
                            } else if (symptomCount == 2) {
                              alpha = 0.6;
                            } else {
                              alpha = 1.0;
                            }
                            cellColor = SymptomColors.symptomBase.withValues(
                              alpha: alpha,
                            );
                            hasSymptom = true;
                          }
                        }
                      } else {
                        // 일반 증상은 symptomData에서 확인 (이 경우는 카테고리가 표시되지 않으므로 사용하지 않음)
                        // 하지만 혹시 모를 경우를 위해 처리
                        hasSymptom = symptoms.contains(labelRow.label);
                        if (hasSymptom) {
                          // 증상이 1개인 경우로 처리
                          cellColor = SymptomColors.symptomBase.withValues(
                            alpha: 0.3,
                          );
                        }
                      }

                      // 모든 셀에 테두리 추가
                      return Padding(
                        padding: EdgeInsets.only(right: 6, bottom: 6),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(2), // 약간 둥근 모서리
                            border: Border.all(
                              color: SymptomColors.border,
                              width: 0.5,
                            ),
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

/// 레이블 행 정보
class _LabelRow {
  final String label;
  final bool isCategory;
  final String? categoryTitle;

  _LabelRow({
    required this.label,
    required this.isCategory,
    this.categoryTitle,
  });
}
