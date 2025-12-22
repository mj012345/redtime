// main.dart
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
// import 'screens/period_tracker_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Period Tracker',
      theme: ThemeData(primarySwatch: Colors.orange, fontFamily: 'Pretendard'),
      home: const PeriodTrackerScreen(),
    );
  }
}

// --------------------------[캘린더 페이지]-----------------------------
//   screens/period_tracker_screen.dart
// import 'package:flutter/material.dart';
// import '../widgets/period_calendar.dart';
// import '../widgets/date_detail_section.dart';
// import '../widgets/custom_bottom_nav.dart';

class PeriodTrackerScreen extends StatefulWidget {
  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> {
  // 달력 상태 관리 (8가지)
  final DateTime today = DateTime.now();
  List<DateTime?> _selectedDates = []; // selectedDay
  List<DateTime> _periodDays = [
    DateTime(2025, 11, 15),
    DateTime(2025, 11, 16),
    DateTime(2025, 11, 17),
    DateTime(2025, 11, 18),
  ];
  List<DateTime> _fertileWindowDays = [
    DateTime(2025, 11, 25),
    DateTime(2025, 11, 26),
    DateTime(2025, 11, 27),
    DateTime(2025, 11, 28),
    DateTime(2025, 11, 29),
  ];
  DateTime? _ovulationDay = DateTime(2025, 11, 28);
  List<DateTime> _expectedPeriodDays = [
    DateTime(2025, 12, 15),
    DateTime(2025, 12, 16),
    DateTime(2025, 12, 17),
    DateTime(2025, 12, 18),
  ];
  List<DateTime> _expectedFertileWindowDays = [
    DateTime(2025, 12, 25),
    DateTime(2025, 12, 26),
    DateTime(2025, 12, 27),
    DateTime(2025, 12, 28),
    DateTime(2025, 12, 29),
  ];
  DateTime? _expectedOvulationDay = DateTime(2025, 12, 28);

  // 기타 상태
  String _selectedType = 'start';
  int _currentBottomNavIndex = 1;
  Set<String> _selectedSymptoms = {}; // 증상 선택 상태

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              PeriodCalendar(
                today: today,
                selectedDates: _selectedDates,
                periodDays: _periodDays,
                fertileWindowDays: _fertileWindowDays,
                ovulationDay: _ovulationDay,
                expectedPeriodDays: _expectedPeriodDays,
                expectedFertileWindowDays: _expectedFertileWindowDays,
                expectedOvulationDay: _expectedOvulationDay,
                onDatesChanged: (dates) {
                  setState(() {
                    _selectedDates = dates;
                    // 날짜 변경 시 해당 날짜의 증상 불러오기 (나중에 데이터 연결)
                    _selectedSymptoms = {};
                  });
                },
              ),
              if (_selectedDates.isNotEmpty && _selectedDates[0] != null)
                DateDetailSection(
                  selectedDate: _selectedDates[0]!,
                  selectedType: _selectedType,
                  onTypeChanged: (type) {
                    setState(() {
                      _selectedType = type;
                    });
                  },
                  selectedSymptoms: _selectedSymptoms,
                  onSymptomToggled: (symptom) {
                    setState(() {
                      if (_selectedSymptoms.contains(symptom)) {
                        _selectedSymptoms.remove(symptom);
                      } else {
                        _selectedSymptoms.add(symptom);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentBottomNavIndex,
        onIndexChanged: (index) {
          setState(() {
            _currentBottomNavIndex = index;
          });
        },
      ),
    );
  }
}

// --------------------------[달력 ] -----------------------------
// widgets/period_calendar.dart
// import 'package:flutter/material.dart';
// import 'package:calendar_date_picker2/calendar_date_picker2.dart';
// import '../utils/date_helper.dart';

class PeriodCalendar extends StatelessWidget {
  final DateTime today;
  final List<DateTime?> selectedDates;
  final List<DateTime> periodDays;
  final List<DateTime> fertileWindowDays;
  final DateTime? ovulationDay;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> expectedFertileWindowDays;
  final DateTime? expectedOvulationDay;
  final Function(List<DateTime?>) onDatesChanged;

  const PeriodCalendar({
    super.key,
    required this.today,
    required this.selectedDates,
    required this.periodDays,
    required this.fertileWindowDays,
    this.ovulationDay,
    required this.expectedPeriodDays,
    required this.expectedFertileWindowDays,
    this.expectedOvulationDay,
    required this.onDatesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final config = CalendarDatePicker2Config(
      calendarType: CalendarDatePicker2Type.single,
      selectedDayHighlightColor: Colors.transparent,
      weekdayLabelTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      // 년/월 선택
      controlsTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      dayTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      disabledDayTextStyle: const TextStyle(color: Colors.grey),
      firstDayOfWeek: 0,
      centerAlignModePicker: true,
      dayBuilder:
          ({
            required date,
            textStyle,
            decoration,
            isSelected,
            isDisabled,
            isToday,
          }) {
            return CalendarDayCell(
              date: date,
              textStyle: textStyle,
              today: today,
              selectedDates: selectedDates,
              periodDays: periodDays,
              fertileWindowDays: fertileWindowDays,
              ovulationDay: ovulationDay,
              expectedPeriodDays: expectedPeriodDays,
              expectedFertileWindowDays: expectedFertileWindowDays,
              expectedOvulationDay: expectedOvulationDay,
            );
          },
      weekdayLabelBuilder: ({required weekday, isScrollViewTopHeader}) {
        return WeekdayLabel(weekday: weekday);
      },
    );

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CalendarDatePicker2(
          config: config,
          value: selectedDates,
          onValueChanged: onDatesChanged,
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// widgets/calendar_day_cell.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';
// import '../utils/date_helper.dart';

class CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final TextStyle? textStyle;
  final DateTime today;
  final List<DateTime?> selectedDates;
  final List<DateTime> periodDays;
  final List<DateTime> fertileWindowDays;
  final DateTime? ovulationDay;
  final List<DateTime> expectedPeriodDays;
  final List<DateTime> expectedFertileWindowDays;
  final DateTime? expectedOvulationDay;

  const CalendarDayCell({
    super.key,
    required this.date,
    this.textStyle,
    required this.today,
    required this.selectedDates,
    required this.periodDays,
    required this.fertileWindowDays,
    this.ovulationDay,
    required this.expectedPeriodDays,
    required this.expectedFertileWindowDays,
    this.expectedOvulationDay,
  });

  @override
  Widget build(BuildContext context) {
    // 실제 날짜 체크
    final isToday = DateHelper.isSameDay(date, today);
    final isPeriod = DateHelper.isDateInList(date, periodDays);
    final isFertile = DateHelper.isDateInList(date, fertileWindowDays);
    final isOvulation =
        ovulationDay != null && DateHelper.isSameDay(date, ovulationDay!);
    final isSelectedDay = DateHelper.isSelectedDate(date, selectedDates);

    // 예상 날짜 체크
    final isExpectedPeriod = DateHelper.isDateInList(date, expectedPeriodDays);
    final isExpectedFertile = DateHelper.isDateInList(
      date,
      expectedFertileWindowDays,
    );
    final isExpectedOvulation =
        expectedOvulationDay != null &&
        DateHelper.isSameDay(date, expectedOvulationDay!);

    Color? bgColor;
    Color? textColor = Colors.black87;
    Color? borderColor;

    // 우선순위: 실제 생리 > 실제 가임기 > 예상 생리 > 예상 가임기 > 선택 > 오늘
    if (isPeriod) {
      bgColor = const Color(0xFFD85A3A);
      textColor = Colors.white;
    } else if (isFertile) {
      bgColor = const Color(0xFFBFD85A);
      textColor = Colors.black87;
    } else if (isExpectedPeriod) {
      bgColor = Colors.transparent;
      borderColor = const Color(0xFFD85A3A).withOpacity(0.5);
      textColor = const Color(0xFFD85A3A).withOpacity(0.7);
    } else if (isExpectedFertile) {
      bgColor = Colors.transparent;
      borderColor = const Color(0xFFBFD85A).withOpacity(0.5);
      textColor = const Color(0xFFBFD85A).withOpacity(0.7);
    } else if (isSelectedDay) {
      bgColor = const Color(0xFFE8E8E8);
    } else if (isToday) {
      bgColor = Colors.transparent;
      borderColor = const Color(0xFF6B4226);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: textStyle?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 실제 배란일 표시
            if (isOvulation)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFC107),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // 예상 배란일 표시
            if (isExpectedOvulation && !isOvulation)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFC107),
                      width: 1,
                    ),
                  ),
                ),
              ),
            // 가임기 텍스트 표시 (실제 가임기일 때만)
            if (isFertile && !isOvulation && !isExpectedFertile)
              Positioned(
                bottom: 0,
                child: Text(
                  '가임기',
                  style: TextStyle(fontSize: 8, color: textColor),
                ),
              ),
            // 오늘 표시 (선택되지 않았을 때만)
            if (isToday &&
                !isSelectedDay &&
                !isPeriod &&
                !isFertile &&
                !isExpectedPeriod &&
                !isExpectedFertile)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6B4226),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// widgets/weekday_label.dart
// import 'package:flutter/material.dart';

class WeekdayLabel extends StatelessWidget {
  final int weekday;

  const WeekdayLabel({super.key, required this.weekday});

  @override
  Widget build(BuildContext context) {
    final labels = ['일', '월', '화', '수', '목', '금', '토'];
    Color textColor = Colors.black87;

    if (weekday == 0 || weekday == 6) {
      textColor = const Color(0xFFFF9999);
    }

    return Center(
      child: Text(
        labels[weekday],
        style: TextStyle(
          color: textColor,
          // fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// widgets/date_detail_section.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';
// import 'period_type_toggle.dart';
// import 'symptom_section.dart';
// import 'status_chips.dart';

class DateDetailSection extends StatelessWidget {
  final DateTime selectedDate;
  final String selectedType;
  final Function(String) onTypeChanged;
  final Set<String> selectedSymptoms;
  final Function(String) onSymptomToggled;

  const DateDetailSection({
    super.key,
    required this.selectedDate,
    required this.selectedType,
    required this.onTypeChanged,
    required this.selectedSymptoms,
    required this.onSymptomToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '11월 ${selectedDate.day}일 금요일',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const StatusChips(),
            const SizedBox(height: 20),
            PeriodTypeToggle(
              selectedType: selectedType,
              onTypeChanged: onTypeChanged,
            ),
            const SizedBox(height: 24),
            SymptomSection(
              title: '통증',
              symptoms: ['두통', '어깨', '허리', '생리통', '팔', '다리'],
              selectedSymptoms: selectedSymptoms,
              onSymptomToggled: onSymptomToggled,
            ),
            const SizedBox(height: 20),
            SymptomSection(
              title: '소화',
              symptoms: ['변비', '설사', '가스/복부팽만', '메스꺼움'],
              selectedSymptoms: selectedSymptoms,
              onSymptomToggled: onSymptomToggled,
            ),
            const SizedBox(height: 20),
            SymptomSection(
              title: '컨디션',
              symptoms: [
                '피곤',
                '집중력 저하',
                '불면증',
                '식욕',
                '성욕',
                '분비물',
                '질건조',
                '질가려움',
                '피부건조',
                '피부가려움',
                '붓푸지',
              ],
              selectedSymptoms: selectedSymptoms,
              onSymptomToggled: onSymptomToggled,
            ),
            const SizedBox(height: 20),
            SymptomSection(
              title: '기분',
              symptoms: ['행복', '불안', '우울', '슬픔', '분노'],
              selectedSymptoms: selectedSymptoms,
              onSymptomToggled: onSymptomToggled,
            ),
            const SizedBox(height: 20),
            SymptomSection(
              title: '기타',
              symptoms: ['관계', '메모'],
              selectedSymptoms: selectedSymptoms,
              onSymptomToggled: onSymptomToggled,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// widgets/status_chips.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';

class StatusChips extends StatelessWidget {
  const StatusChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '생리 시작 1일째',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF8BC34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '임신 확률 높음',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------
// widgets/period_type_toggle.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';

class PeriodTypeToggle extends StatelessWidget {
  final String selectedType;
  final Function(String) onTypeChanged;

  const PeriodTypeToggle({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            isSelected: selectedType == 'start',
            icon: '💧',
            label: '생리 시작',
            onTap: () => onTypeChanged('start'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleButton(
            isSelected: selectedType == 'end',
            icon: '⊘',
            label: '생리 종료',
            onTap: () => onTypeChanged('end'),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool isSelected;
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3CD) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black87 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// // widgets/symptom_section.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';
// import 'symptom_chip.dart';

class SymptomSection extends StatelessWidget {
  final String title;
  final List<String> symptoms;
  final Set<String> selectedSymptoms;
  final Function(String) onSymptomToggled;

  const SymptomSection({
    super.key,
    required this.title,
    required this.symptoms,
    required this.selectedSymptoms,
    required this.onSymptomToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC107),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: symptoms
              .map(
                (symptom) => SymptomChip(
                  label: symptom,
                  isSelected: selectedSymptoms.contains(symptom),
                  onTap: () => onSymptomToggled(symptom),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// -------------------------------------------------------
// widgets/symptom_chip.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';

class SymptomChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SymptomChip({
    super.key,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3CD) : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFC107)
                : const Color(0xFFE0E0E0),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? const Color(0xFF6B4226) : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// widgets/custom_bottom_nav.dart
// -------------------------------------------------------
// import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.home_outlined,
                label: '홈',
                index: 0,
                currentIndex: currentIndex,
                onTap: onIndexChanged,
              ),
              _BottomNavItem(
                icon: Icons.calendar_today,
                label: '',
                index: 1,
                currentIndex: currentIndex,
                onTap: onIndexChanged,
                isCenter: true,
              ),
              _BottomNavItem(
                icon: Icons.trending_up,
                label: '리포트',
                index: 2,
                currentIndex: currentIndex,
                onTap: onIndexChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;
  final bool isCenter;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;

    if (isCenter) {
      return GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFF6B4226),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF6B4226) : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? const Color(0xFF6B4226) : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// utils/date_helper.dart
// -------------------------------------------------------

class DateHelper {
  // 날짜 비교 유틸리티 함수들
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool isDateInList(DateTime date, List<DateTime> dateList) {
    return dateList.any((d) => isSameDay(date, d));
  }

  static bool isSelectedDate(DateTime date, List<DateTime?> selectedDates) {
    if (selectedDates.isEmpty) return false;
    final selected = selectedDates[0];
    if (selected == null) return false;
    return isSameDay(date, selected);
  }
}
