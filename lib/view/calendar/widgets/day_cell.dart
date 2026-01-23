import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:red_time_app/theme/app_colors.dart';

class DayCell extends StatefulWidget {
  final DateTime date;
  final bool isOutsideMonth;
  final VoidCallback onTap;
  final bool isPeriod;
  final bool isFertile;
  final bool isOvulation;
  final bool isExpectedPeriod;
  final bool isExpectedFertile;
  final bool isExpectedPeriodStart;
  final bool isExpectedOvulation;
  final bool isToday;
  final bool isSelected;
  final bool hasRecord;
  final int symptomCount;
  final bool hasMemo;
  final bool hasRelationship;
  final bool isPeriodStart;
  final bool isPeriodEnd;
  final bool isFertileStart;
  final bool isFertileEnd;
  final DateTime? today;
  final bool isActive; // 현재 탭이 활성화 상태인지 여부

  const DayCell({
    super.key,
    required this.date,
    required this.isOutsideMonth,
    required this.onTap,
    required this.isPeriod,
    required this.isFertile,
    required this.isOvulation,
    required this.isExpectedPeriod,
    required this.isExpectedFertile,
    required this.isExpectedPeriodStart,
    required this.isExpectedOvulation,
    required this.isToday,
    required this.isSelected,
    required this.hasRecord,
    this.symptomCount = 0,
    this.hasMemo = false,
    this.hasRelationship = false,
    required this.isPeriodStart,
    required this.isPeriodEnd,
    required this.isFertileStart,
    required this.isFertileEnd,
    this.today,
    this.isActive = true,
  });

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.2, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if ((widget.isExpectedPeriod || widget.isExpectedFertile) && widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = (widget.isExpectedPeriod || widget.isExpectedFertile) && widget.isActive;
    
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showPeriod = !widget.isOutsideMonth && widget.isPeriod;
    final showFertile = !widget.isOutsideMonth && widget.isFertile;
    final showExpectedPeriod = !widget.isOutsideMonth && widget.isExpectedPeriod;
    final showExpectedFertile = !widget.isOutsideMonth && widget.isExpectedFertile;
    final showOvulation = !widget.isOutsideMonth && widget.isOvulation;
    final showSelected = !widget.isOutsideMonth && widget.isSelected;

    Color? bgColor;

    final isFutureDate = widget.today != null &&
        !widget.isOutsideMonth &&
        DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
        ).isAfter(DateTime(widget.today!.year, widget.today!.month, widget.today!.day));

    Color textColor = widget.isOutsideMonth
        ? AppColors.textDisabled.withValues(alpha: 0.5)
        : isFutureDate
            ? AppColors.textPrimary.withValues(alpha: 0.5)
            : widget.isToday
                ? AppColors.textPrimaryLight
                : AppColors.textPrimary;
    Color? borderColor;

    if (showPeriod) {
      bgColor = SymptomColors.period;
      // 오늘 날짜인 경우 textPrimaryLight 유지, 아니면 textPrimary
      if (!widget.isToday) {
        textColor = AppColors.textPrimary;
      }
    } else if (showFertile) {
      bgColor = SymptomColors.fertile;
    }

    if (showSelected) {
      borderColor = isFutureDate ? AppColors.textDisabled : AppColors.primary;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 배경 애니메이션 처리 (예상일일 때만)
          if (showExpectedPeriod || showExpectedFertile)
            Positioned.fill(
              child: RepaintBoundary(
                child: FadeTransition(
                  opacity: _animation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: showExpectedPeriod
                          ? SymptomColors.period
                          : SymptomColors.fertile,
                      borderRadius: BorderRadius.only(
                        topLeft: widget.isPeriodStart || widget.isFertileStart
                            ? const Radius.circular(8)
                            : Radius.zero,
                        bottomLeft: widget.isPeriodStart || widget.isFertileStart
                            ? const Radius.circular(8)
                            : Radius.zero,
                        topRight: widget.isPeriodEnd || widget.isFertileEnd
                            ? const Radius.circular(8)
                            : Radius.zero,
                        bottomRight: widget.isPeriodEnd || widget.isFertileEnd
                            ? const Radius.circular(8)
                            : Radius.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                topLeft: (showPeriod && widget.isPeriodStart) ||
                        (showFertile && widget.isFertileStart)
                    ? const Radius.circular(8)
                    : Radius.zero,
                bottomLeft: (showPeriod && widget.isPeriodStart) ||
                        (showFertile && widget.isFertileStart)
                    ? const Radius.circular(8)
                    : Radius.zero,
                topRight: (showPeriod && widget.isPeriodEnd) ||
                        (showFertile && widget.isFertileEnd)
                    ? const Radius.circular(8)
                    : Radius.zero,
                bottomRight: (showPeriod && widget.isPeriodEnd) ||
                        (showFertile && widget.isFertileEnd)
                    ? const Radius.circular(8)
                    : Radius.zero,
              ),
              border: showSelected
                  ? Border.all(
                      color: borderColor!,
                      width: 1,
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 3,
                right: 3,
                top: 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 1),
                  SizedBox(
                    height: 14,
                    child: Center(
                      child: Text(
                        '${widget.date.day}',
                        style: TextStyle(
                          fontSize: widget.isToday ? 12 : 11,
                          fontWeight:
                              widget.isToday ? FontWeight.w700 : FontWeight.w300,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 12,
                    child: widget.isOutsideMonth
                        ? const SizedBox.shrink()
                        : Center(
                            child: _buildMiddleIndicator(
                              isPeriod: showPeriod,
                              isPeriodStart: widget.isPeriodStart,
                              isPeriodEnd: widget.isPeriodEnd,
                              isFertile: showFertile,
                              isOvulation: showOvulation,
                              isFertileStart: widget.isFertileStart,
                              isExpectedPeriod: showExpectedPeriod,
                              isExpectedPeriodStart: widget.isExpectedPeriodStart,
                              isExpectedOvulation: widget.isExpectedOvulation,
                              isExpectedFertile: showExpectedFertile,
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 12,
                    child: widget.isOutsideMonth
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.hasRelationship) ...[
                                const Icon(
                                  Icons.favorite,
                                  size: 10,
                                  color: SymptomColors.relationship,
                                ),
                                if (widget.hasRecord || widget.hasMemo)
                                  const SizedBox(width: 1),
                              ],
                              if (widget.hasRecord) ...[
                                const Icon(
                                  Icons.local_hospital,
                                  size: 10,
                                  color: SymptomColors.symptomBase,
                                ),
                                if (widget.hasMemo) const SizedBox(width: 1),
                              ],
                              if (widget.hasMemo)
                                const Icon(
                                  CupertinoIcons.doc_text_fill,
                                  size: 10,
                                  color: SymptomColors.memo,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleIndicator({
    required bool isPeriod,
    required bool isPeriodStart,
    required bool isPeriodEnd,
    required bool isFertile,
    required bool isOvulation,
    required bool isFertileStart,
    required bool isExpectedPeriod,
    required bool isExpectedPeriodStart,
    required bool isExpectedOvulation,
    required bool isExpectedFertile,
  }) {
    Widget? indicator;
    if (isPeriod && isPeriodStart && isPeriodEnd) {
      indicator = const Text(
        '시작/종료',
        style: TextStyle(
            fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isPeriod && isPeriodStart) {
      indicator = const Text(
        '시작',
        style: TextStyle(
            fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isPeriod && isPeriodEnd) {
      indicator = const Text(
        '종료',
        style: TextStyle(
            fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isOvulation) {
      indicator = const Text(
        '배란일',
        style: TextStyle(
            fontSize: 8, color: Color(0xFF55B292), fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isExpectedOvulation) {
      indicator = const Text(
        '배란예정',
        style: TextStyle(
            fontSize: 8, color: Color(0xFF55B292), fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if (isExpectedPeriod && isExpectedPeriodStart) {
      indicator = const Text(
        '생리예정',
        style: TextStyle(
            fontSize: 8, color: Color(0xFFF87171), fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    } else if ((isFertile || isExpectedFertile) &&
        !isOvulation &&
        !isExpectedOvulation &&
        isFertileStart) {
      indicator = const Text(
        '가임기',
        style: TextStyle(
            fontSize: 8, color: Color(0xFF55B292), fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.visible,
      );
    }

    if (indicator == null) {
      return const SizedBox.shrink();
    }
    return indicator;
  }
}
