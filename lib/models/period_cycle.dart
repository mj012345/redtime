/// 생리 주기 모델: 시작/종료일과 유틸리티 메서드
class PeriodCycle {
  DateTime start;
  DateTime? end;

  PeriodCycle(this.start, this.end);

  List<DateTime> toDays() {
    final s = DateTime(start.year, start.month, start.day);
    final e = end ?? s;
    final realEnd = e.isBefore(s) ? s : e;
    final days = <DateTime>[];
    var cur = s;
    while (!cur.isAfter(realEnd)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  bool contains(DateTime d) {
    final s = DateTime(start.year, start.month, start.day);
    final e = end ?? s;
    final realEnd = e.isBefore(s) ? s : e;
    return !d.isBefore(s) && !d.isAfter(realEnd);
  }
}

