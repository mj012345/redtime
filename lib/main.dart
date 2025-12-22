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

// screens/period_tracker_screen.dart
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
  List<DateTime?> _selectedDates = [];
  String _selectedType = 'start';
  int _currentBottomNavIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              PeriodCalendar(
                selectedDates: _selectedDates,
                onDatesChanged: (dates) {
                  setState(() {
                    _selectedDates = dates;
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

// widgets/period_calendar.dart
// import 'package:flutter/material.dart';
// import 'package:calendar_date_picker2/calendar_date_picker2.dart';
// import '../utils/date_helper.dart';

class PeriodCalendar extends StatelessWidget {
  final List<DateTime?> selectedDates;
  final Function(List<DateTime?>) onDatesChanged;

  const PeriodCalendar({
    super.key,
    required this.selectedDates,
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
              selectedDates: selectedDates,
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

// widgets/calendar_day_cell.dart
// import 'package:flutter/material.dart';
// import '../utils/date_helper.dart';

class CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final TextStyle? textStyle;
  final List<DateTime?> selectedDates;

  const CalendarDayCell({
    super.key,
    required this.date,
    this.textStyle,
    required this.selectedDates,
  });

  @override
  Widget build(BuildContext context) {
    final isPeriod = DateHelper.isPeriodDate(date);
    final isFertile = DateHelper.isFertileDate(date);
    final isOvulation = DateHelper.isOvulationDate(date);
    final isSelectedDay = DateHelper.isSelectedDate(date, selectedDates);

    Color? bgColor;
    Color? textColor = Colors.black87;

    if (isPeriod) {
      bgColor = const Color(0xFFD85A3A);
      textColor = Colors.white;
    } else if (isFertile) {
      bgColor = const Color(0xFFBFD85A);
      textColor = Colors.black87;
    } else if (isSelectedDay) {
      bgColor = const Color(0xFFE8E8E8);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
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
            if (date.day == 25)
              Positioned(
                bottom: 0,
                child: Text(
                  '가와기',
                  style: TextStyle(fontSize: 8, color: textColor),
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

    if (weekday == 0) {
      textColor = const Color(0xFFFF9999);
    } else if (weekday == 6) {
      textColor = const Color(0xFF9999FF);
    }

    return Center(
      child: Text(
        labels[weekday],
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

// widgets/date_detail_section.dart
// import 'package:flutter/material.dart';
// import 'period_type_toggle.dart';
// import 'symptom_section.dart';
// import 'status_chips.dart';

class DateDetailSection extends StatelessWidget {
  final DateTime selectedDate;
  final String selectedType;
  final Function(String) onTypeChanged;

  const DateDetailSection({
    super.key,
    required this.selectedDate,
    required this.selectedType,
    required this.onTypeChanged,
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
            const SymptomSection(
              title: '통증',
              symptoms: ['두통', '어깨', '허리', '생리통', '팔', '다리'],
            ),
            const SizedBox(height: 20),
            const SymptomSection(
              title: '소화',
              symptoms: ['변비', '설사', '가스/복부팽만', '메스꺼움'],
            ),
            const SizedBox(height: 20),
            const SymptomSection(
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
            ),
            const SizedBox(height: 20),
            const SymptomSection(
              title: '기분',
              symptoms: ['행복', '불안', '우울', '슬픔', '분노'],
            ),
            const SizedBox(height: 20),
            const SymptomSection(title: '기타', symptoms: ['관계', '메모']),
          ],
        ),
      ),
    );
  }
}

// widgets/status_chips.dart
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

// widgets/period_type_toggle.dart
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

// // widgets/symptom_section.dart
// import 'package:flutter/material.dart';
// import 'symptom_chip.dart';

class SymptomSection extends StatelessWidget {
  final String title;
  final List<String> symptoms;

  const SymptomSection({
    super.key,
    required this.title,
    required this.symptoms,
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
              .map((symptom) => SymptomChip(label: symptom))
              .toList(),
        ),
      ],
    );
  }
}

// widgets/symptom_chip.dart
// import 'package:flutter/material.dart';

class SymptomChip extends StatelessWidget {
  final String label;

  const SymptomChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
      ),
    );
  }
}

// widgets/custom_bottom_nav.dart
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

// utils/date_helper.dart
class DateHelper {
  static final List<DateTime> periodDates = [
    DateTime(2025, 11, 15),
    DateTime(2025, 11, 16),
    DateTime(2025, 11, 17),
    DateTime(2025, 11, 18),
  ];

  static final DateTime ovulationDate = DateTime(2025, 11, 1);

  static final List<DateTime> fertileDates = [
    DateTime(2025, 11, 25),
    DateTime(2025, 11, 26),
    DateTime(2025, 11, 27),
    DateTime(2025, 11, 28),
    DateTime(2025, 11, 29),
  ];

  static bool isPeriodDate(DateTime date) {
    return periodDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
  }

  static bool isFertileDate(DateTime date) {
    return fertileDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
  }

  static bool isOvulationDate(DateTime date) {
    return ovulationDate.year == date.year &&
        ovulationDate.month == date.month &&
        ovulationDate.day == date.day;
  }

  static bool isSelectedDate(DateTime date, List<DateTime?> selectedDates) {
    if (selectedDates.isEmpty) return false;
    final selected = selectedDates[0];
    if (selected == null) return false;
    return selected.year == date.year &&
        selected.month == date.month &&
        selected.day == date.day;
  }
}
