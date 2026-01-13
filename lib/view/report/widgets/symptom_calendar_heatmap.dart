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

  _CategoryLabel({required this.categoryTitle, required this.symptoms});
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

  /// 예시 모드 (데이터가 없을 때 회색으로 표시)
  final bool isExample;

  const SymptomCalendarHeatmap({
    super.key,
    required this.symptomData,
    required this.periodDays,
    required this.fertileWindowDays,
    required this.symptomCatalog,
    required this.startDate,
    required this.endDate,
    this.isExample = false,
  });

  @override
  State<SymptomCalendarHeatmap> createState() => _SymptomCalendarHeatmapState();
}

class _SymptomCalendarHeatmapState extends State<SymptomCalendarHeatmap> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;
  String? _selectedCellKey; // 선택된 셀의 키 (날짜_레이블)
  OverlayEntry? _tooltipOverlay; // 현재 표시 중인 툴팁

  // Lazy loading을 위한 상태
  late DateTime _displayedStartDate; // 현재 표시 중인 시작 날짜
  bool _isLoadingMore = false; // 추가 데이터 로딩 중인지
  static const int _initialDays = 60; // 초기 표시 일수
  static const int _loadMoreDays = 60; // 추가 로드할 일수

  // 현재 보이는 첫 번째 날짜의 년/월 (스크롤 위치 기반)
  String? _visibleFirstMonthYear;

  // 캐시된 데이터
  List<DateTime>? _cachedDates;
  List<_LabelRow>? _cachedLabelRows;
  Map<String, Set<String>>? _cachedSymptomData;
  List<DateTime>? _cachedPeriodDays;
  List<DateTime>? _cachedFertileWindowDays;
  bool? _cachedIsExample;

  @override
  void initState() {
    super.initState();
    // 초기 표시 시작 날짜 설정 (최근 60일)
    final endDate = DateTime(
      widget.endDate.year,
      widget.endDate.month,
      widget.endDate.day,
    );

    // 최초 화면 진입 시에는 항상 최근 60일만 표시
    _displayedStartDate = endDate.subtract(
      const Duration(days: _initialDays - 1),
    );

    // 실제 시작 날짜보다 이전으로 가지 않도록 제한
    final actualStartDate = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
    if (_displayedStartDate.isBefore(actualStartDate)) {
      _displayedStartDate = actualStartDate;
    }

    // 스크롤 리스너: 툴팁 닫기 + lazy loading
    _scrollController.addListener(_onScroll);

    // 초기 데이터 캐싱
    _updateCache();

    // 초기 월 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateVisibleMonth();
    });
  }

  /// 최대 표시 가능한 시작 날짜 계산 (오늘이 1월이면 작년 1월 1일까지)
  DateTime _getMaxStartDate() {
    final endDate = DateTime(
      widget.endDate.year,
      widget.endDate.month,
      widget.endDate.day,
    );

    // 오늘이 1월이면 작년 1월 1일까지, 그 외에는 widget.startDate까지
    if (endDate.month == 1) {
      return DateTime(endDate.year - 1, 1, 1);
    }

    // 실제 시작 날짜 반환
    return DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
  }

  /// 스크롤 이벤트 처리
  void _onScroll() {
    // 툴팁 닫기
    if (_scrollController.hasClients && _tooltipOverlay != null) {
      _hideTooltipOnly();
    }

    // 현재 보이는 첫 번째 날짜의 월 업데이트
    _updateVisibleMonth();

    // 왼쪽 끝에 도달했는지 확인 (추가 데이터 로드)
    if (_scrollController.hasClients && !_isLoadingMore) {
      final position = _scrollController.position;
      final maxStartDate = _getMaxStartDate();
      // 왼쪽 끝에서 100픽셀 이내에 도달하면 추가 데이터 로드
      if (position.pixels <= 100 && _displayedStartDate.isAfter(maxStartDate)) {
        _loadMoreData();
      }
    }
  }

  /// 현재 보이는 첫 번째 날짜의 월 업데이트
  void _updateVisibleMonth() {
    if (!_scrollController.hasClients ||
        _cachedDates == null ||
        _cachedDates!.isEmpty) {
      return;
    }

    final scrollPosition = _scrollController.position.pixels;
    // 셀 너비 (16) + 간격 (6) = 22
    const cellWidth = 22.0;

    // 스크롤 위치를 기반으로 첫 번째 보이는 날짜 인덱스 계산
    final firstVisibleIndex = (scrollPosition / cellWidth).floor();

    if (firstVisibleIndex >= 0 && firstVisibleIndex < _cachedDates!.length) {
      final firstVisibleDate = _cachedDates![firstVisibleIndex];
      // 년도 2자리로 표시 (예: 25/1)
      final year = firstVisibleDate.year % 100;
      final monthYear = '$year/${firstVisibleDate.month}';

      if (_visibleFirstMonthYear != monthYear) {
        setState(() {
          _visibleFirstMonthYear = monthYear;
        });
      }
    }
  }

  /// 추가 데이터 로드
  void _loadMoreData() {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 이전 날짜로 시작 날짜 확장
    final newStartDate = _displayedStartDate.subtract(
      const Duration(days: _loadMoreDays),
    );

    // 최대 표시 가능한 시작 날짜 가져오기
    final maxStartDate = _getMaxStartDate();

    // 최대 시작 날짜보다 이전으로 가지 않도록 제한
    if (newStartDate.isBefore(maxStartDate)) {
      _displayedStartDate = maxStartDate;
    } else {
      _displayedStartDate = newStartDate;
    }

    // 캐시 업데이트
    _updateCache();

    // 스크롤 위치 유지 (새로운 데이터가 왼쪽에 추가되므로)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        // 스크롤 위치 조정은 필요 없음 (새 데이터가 왼쪽에 추가되므로)
        setState(() {
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(SymptomCalendarHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때 데이터가 변경되었는지 확인
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.symptomData != widget.symptomData ||
        oldWidget.periodDays != widget.periodDays ||
        oldWidget.fertileWindowDays != widget.fertileWindowDays ||
        oldWidget.isExample != widget.isExample ||
        oldWidget.symptomCatalog != widget.symptomCatalog) {
      // 전체 데이터 범위가 변경되면 초기화 (최근 60일부터)
      final endDate = DateTime(
        widget.endDate.year,
        widget.endDate.month,
        widget.endDate.day,
      );

      // 최초 화면 진입 시에는 항상 최근 60일만 표시
      _displayedStartDate = endDate.subtract(
        const Duration(days: _initialDays - 1),
      );

      // 실제 시작 날짜보다 이전으로 가지 않도록 제한
      final maxStartDate = _getMaxStartDate();
      if (_displayedStartDate.isBefore(maxStartDate)) {
        _displayedStartDate = maxStartDate;
      }

      _updateCache();
    }
  }

  /// 캐시 업데이트
  void _updateCache() {
    // 날짜 리스트 생성 (표시 중인 시작 날짜부터 종료 날짜까지)
    final dates = <DateTime>[];
    var current = DateTime(
      _displayedStartDate.year,
      _displayedStartDate.month,
      _displayedStartDate.day,
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

    _cachedDates = dates;
    _cachedLabelRows = _generateLabelRows();
    _cachedSymptomData = widget.symptomData;
    _cachedPeriodDays = widget.periodDays;
    _cachedFertileWindowDays = widget.fertileWindowDays;
    _cachedIsExample = widget.isExample;
  }

  @override
  void dispose() {
    _hideTooltip();
    _scrollController.dispose();
    super.dispose();
  }

  /// 툴팁만 숨기기 (셀 선택 상태는 유지)
  void _hideTooltipOnly() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  /// 툴팁 숨기기 및 셀 선택 해제
  void _hideTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
    if (mounted) {
      setState(() {
        _selectedCellKey = null;
      });
    }
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
    // 카테고리 이름에 슬래시가 포함될 수 있으므로 마지막 슬래시를 기준으로 분리
    final lastSlashIndex = symptom.lastIndexOf('/');
    if (lastSlashIndex != -1) {
      return symptom.substring(0, lastSlashIndex); // 카테고리 반환
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
    // 카테고리 이름에 슬래시가 포함될 수 있으므로 마지막 슬래시를 기준으로 분리
    final lastSlashIndex = symptom.lastIndexOf('/');
    if (lastSlashIndex != -1) {
      return symptom.substring(lastSlashIndex + 1); // 증상 이름만 반환
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

  /// 색상을 더 진하게 만드는 함수
  Color _darkenColor(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// 증상 다이얼로그 표시
  void _showSymptomDialog(
    BuildContext context,
    DateTime date,
    Set<String> symptoms,
    _LabelRow? labelRow,
    Offset tapPosition,
  ) {
    // 생리일 여부 확인
    final isPeriodDay = widget.periodDays.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    // 가임기 여부 확인
    final isFertileDay = widget.fertileWindowDays.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    // 증상 텍스트 리스트 생성
    final List<String> symptomTexts = [];

    // 선택된 카테고리에 해당하는 증상만 표시
    if (labelRow != null) {
      if (labelRow.label == '생리일') {
        if (isPeriodDay) {
          symptomTexts.add('생리일');
        }
      } else if (labelRow.label == '가임기') {
        if (isFertileDay) {
          symptomTexts.add('가임기');
        }
      } else if (labelRow.isCategory) {
        // 카테고리 행인 경우, 해당 카테고리의 증상만 표시
        final categoryName = labelRow.label;
        final categorySymptoms = <String>[];

        for (final symptom in symptoms) {
          if (symptom == '메모') {
            continue;
          }
          // 카테고리 이름에 슬래시가 포함될 수 있으므로 마지막 슬래시를 기준으로 분리
          final lastSlashIndex = symptom.lastIndexOf('/');
          if (lastSlashIndex != -1) {
            final symptomCategory = symptom.substring(0, lastSlashIndex);
            final symptomName = symptom.substring(lastSlashIndex + 1);
            if (symptomCategory == categoryName) {
              categorySymptoms.add(symptomName);
            }
          }
        }

        // '좋음'만 있어도 표시
        if (categorySymptoms.isNotEmpty) {
          // 카테고리명 제외하고 증상만 표시 (가로로 나열)
          symptomTexts.add(categorySymptoms.join(', '));
        } else {
          // '좋음'이 있는지 확인 (다른 증상은 없지만 '좋음'만 있는 경우)
          final hasGood = symptoms.contains('${categoryName}/좋음');
          if (hasGood) {
            symptomTexts.add('좋음');
          }
        }
      }
    } else {
      // labelRow가 없는 경우 (일반적으로 발생하지 않음)
      // 모든 증상 표시
      final List<String> allSymptoms = [];

      for (final symptom in symptoms) {
        if (symptom == '메모') {
          continue;
        }
        if (symptom.contains('/')) {
          final parts = symptom.split('/');
          if (parts.length == 2) {
            allSymptoms.add(parts[1]);
          }
        } else {
          allSymptoms.add(symptom);
        }
      }

      if (isPeriodDay) {
        symptomTexts.add('생리일');
      }
      if (isFertileDay) {
        symptomTexts.add('가임기');
      }

      symptomTexts.addAll(allSymptoms);
    }

    // 증상이 없는 경우
    if (symptomTexts.isEmpty) {
      symptomTexts.add('기록된 증상이 없습니다.');
    }

    // 기존 툴팁이 있으면 먼저 제거 (셀 선택 상태는 유지)
    _hideTooltipOnly();

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    final cellSize = 20.0; // 셀 크기
    final tooltipOffset = -3.0; // 툴팁 오프셋 (셀과 약간 겹치도록)
    final horizontalPadding = 10.0; // 툴팁 좌우 패딩

    // 텍스트의 실제 너비 계산
    final textStyle = AppTextStyles.body.copyWith(
      fontSize: 10,
      color: AppColors.textPrimary,
    );
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: symptomTexts.isEmpty
            ? '기록된 증상이 없습니다.'
            : symptomTexts.reduce((a, b) => a.length > b.length ? a : b),
        style: textStyle,
      ),
    );
    textPainter.layout();
    final maxTextWidth = textPainter.size.width;
    final popupWidth = maxTextWidth + horizontalPadding * 2;
    final popupHeight = symptomTexts.length * 20.0 + 12.0; // 툴팁 높이 추정

    // 기본: 셀의 오른쪽 하단 (셀과 약간 겹치도록)
    double left = tapPosition.dx + cellSize / 2 + tooltipOffset;
    double top = tapPosition.dy + cellSize / 2 + tooltipOffset;

    // 오른쪽에 공간이 부족하면 왼쪽 하단으로 표시
    if (left + popupWidth > screenSize.width - 8) {
      // 툴팁의 오른쪽 끝이 셀의 왼쪽 끝과 가깝게 표시 (셀과 약간 겹치도록)
      left = tapPosition.dx - cellSize / 2 - popupWidth - tooltipOffset;
    }

    // 왼쪽 경계 체크
    if (left < 8) {
      left = 8;
    }

    // 아래쪽 경계 체크
    if (top + popupHeight > screenSize.height - 8) {
      top = screenSize.height - popupHeight - 8;
    }

    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...symptomTexts.map(
                  (text) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      text,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 10,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_tooltipOverlay!);
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

    return categoryLabels;
  }

  /// 모든 레이블 행 생성 (카테고리만)
  List<_LabelRow> _generateLabelRows() {
    final rows = <_LabelRow>[];

    // 고정 레이블
    rows.add(_LabelRow(label: '생리일', isCategory: false));
    rows.add(_LabelRow(label: '가임기', isCategory: false));

    // 예시 모드인 경우 모든 카테고리 표시
    if (widget.isExample) {
      for (final category in widget.symptomCatalog) {
        // '기타' 카테고리는 제외 (관계, 메모만 포함)
        if (category.title == '기타') continue;

        rows.add(
          _LabelRow(
            label: category.title,
            isCategory: true,
            categoryTitle: category.title,
          ),
        );
      }
      return rows;
    }

    // 카테고리별 레이블 (달력 페이지 순서 유지)
    final categoryLabels = _generateCategoryLabels();
    final categoryLabelMap = <String, _CategoryLabel>{};
    for (final categoryLabel in categoryLabels) {
      categoryLabelMap[categoryLabel.categoryTitle] = categoryLabel;
    }

    // symptomCatalog 순서대로 레이블 추가
    for (final category in widget.symptomCatalog) {
      // '기타' 카테고리는 제외 (관계, 메모만 포함)
      if (category.title == '기타') continue;

      // 해당 카테고리에 증상이 기록되어 있는 경우에만 추가
      if (categoryLabelMap.containsKey(category.title)) {
        rows.add(
          _LabelRow(
            label: category.title,
            isCategory: true,
            categoryTitle: category.title,
          ),
        );
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    // 캐시된 데이터 사용
    final dates = _cachedDates ?? [];
    final labelRows = _cachedLabelRows ?? [];

    // 빌드 완료 후 오른쪽 끝으로 스크롤 및 월 업데이트
    if (!_hasScrolledToEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && !_hasScrolledToEnd) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          _hasScrolledToEnd = true;
          _updateVisibleMonth();
        }
      });
    } else {
      // 이미 스크롤된 경우 현재 월 업데이트
      _updateVisibleMonth();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 세로/가로 스크롤 모두 감지하여 툴팁만 닫기 (셀 선택 상태는 유지)
        if (_tooltipOverlay != null) {
          _hideTooltipOnly();
        }
        return false; // 다른 리스너도 처리할 수 있도록 false 반환
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레이블 컬럼 (고정)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 월 표시 헤더
              SizedBox(
                height: 22,
                width: 30,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _visibleFirstMonthYear ?? '',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // 레이블들 (셀 높이 16 + 하단 간격 6 = 22)
              ...labelRows.map((labelRow) {
                return SizedBox(
                  height: 22,
                  width: 30,
                  child: Align(
                    alignment: Alignment(1.0, -0.5),
                    child: Text(
                      labelRow.label,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                );
              }),
            ],
          ),
          SizedBox(width: 5),
          // 날짜 헤더와 그리드 (스크롤 가능, 동기화)
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 헤더 (셀 높이 16 + 하단 간격 6 = 22)
                  SizedBox(
                    height: 22,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                            width: 16,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: dates.asMap().entries.map((dateEntry) {
                        final date = dateEntry.value;

                        // 해당 레이블의 증상이 있는지 확인
                        final dateKey =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final symptoms =
                            (_cachedSymptomData ??
                                widget.symptomData)[dateKey] ??
                            <String>{};

                        bool hasSymptom = false;
                        Color cellColor = AppColors.disabled;

                        // 생리일과 가임기는 별도 처리
                        final periodDays =
                            _cachedPeriodDays ?? widget.periodDays;
                        final fertileWindowDays =
                            _cachedFertileWindowDays ??
                            widget.fertileWindowDays;
                        final isExample = _cachedIsExample ?? widget.isExample;

                        if (labelRow.label == '생리일') {
                          hasSymptom = periodDays.any(
                            (d) =>
                                d.year == date.year &&
                                d.month == date.month &&
                                d.day == date.day,
                          );
                          if (hasSymptom) {
                            cellColor = isExample
                                ? AppColors.textDisabled.withValues(alpha: 0.3)
                                : SymptomColors.period;
                          }
                        } else if (labelRow.label == '가임기') {
                          hasSymptom = fertileWindowDays.any(
                            (d) =>
                                d.year == date.year &&
                                d.month == date.month &&
                                d.day == date.day,
                          );
                          if (hasSymptom) {
                            cellColor = isExample
                                ? AppColors.textDisabled.withValues(alpha: 0.2)
                                : SymptomColors.fertile;
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
                            cellColor = isExample
                                ? AppColors.textDisabled.withValues(alpha: 0.3)
                                : SymptomColors.goodSymptom;
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
                              cellColor = isExample
                                  ? AppColors.textDisabled.withValues(
                                      alpha: alpha,
                                    )
                                  : SymptomColors.symptomBase.withValues(
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

                        // 셀 키 생성 (날짜_레이블)
                        final cellKey =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}_${labelRow.label}';
                        final isSelected = _selectedCellKey == cellKey;

                        // 셀 색상에 따라 테두리 색상 결정
                        Color borderColor = SymptomColors.border;
                        if (isSelected && cellColor != AppColors.disabled) {
                          // 셀 색상보다 약간 진한 색상으로 테두리
                          borderColor = _darkenColor(cellColor, 0.1);
                        } else if (isSelected) {
                          // 선택되었지만 기본 색상인 경우
                          borderColor = AppColors.textSecondary;
                        }

                        // 모든 셀에 테두리 추가
                        return RepaintBoundary(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              // 간격 영역을 터치해도 툴팁 제거
                              if (!hasSymptom) {
                                _hideTooltip();
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.only(right: 6, bottom: 6),
                              child: Builder(
                                builder: (cellContext) {
                                  return GestureDetector(
                                    onTapDown: (details) {
                                      if (hasSymptom) {
                                        // 증상이 있는 셀: 툴팁 표시
                                        // 기존 툴팁이 있으면 먼저 닫기 (셀 선택 상태는 유지)
                                        _hideTooltipOnly();

                                        // 선택된 셀 업데이트
                                        setState(() {
                                          _selectedCellKey = cellKey;
                                        });

                                        // 터치 위치를 전역 좌표로 변환
                                        final RenderBox? box =
                                            cellContext.findRenderObject()
                                                as RenderBox?;
                                        if (box != null) {
                                          // 셀의 중심 위치 계산
                                          final cellCenter = box.localToGlobal(
                                            Offset(
                                              box.size.width / 2,
                                              box.size.height / 2,
                                            ),
                                          );

                                          // 다음 프레임에서 툴팁 표시
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                if (mounted &&
                                                    _selectedCellKey ==
                                                        cellKey) {
                                                  _showSymptomDialog(
                                                    cellContext,
                                                    date,
                                                    symptoms,
                                                    labelRow,
                                                    cellCenter,
                                                  );
                                                }
                                              });
                                        }
                                      } else {
                                        // 증상이 없는 셀: 툴팁 제거 및 선택 해제
                                        _hideTooltip();
                                      }
                                    },
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: cellColor,
                                        borderRadius: BorderRadius.circular(
                                          2,
                                        ), // 약간 둥근 모서리
                                        border: Border.all(
                                          color: borderColor,
                                          width: isSelected ? 1.5 : 0.5,
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
      ),
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
