/// 증상 선택 기록 데이터 접근 추상화 (날짜 키: yyyy-MM-dd -> 증상 Set)
abstract class SymptomRepository {
  Map<String, Set<String>> loadSelections();
  void saveSelections(Map<String, Set<String>> selections);
}

/// 기본 인메모리 구현 (임시 저장 용)
class InMemorySymptomRepository implements SymptomRepository {
  Map<String, Set<String>> _store = {};

  @override
  Map<String, Set<String>> loadSelections() =>
      _store.map((k, v) => MapEntry(k, Set<String>.from(v)));

  @override
  void saveSelections(Map<String, Set<String>> selections) {
    _store = selections.map((k, v) => MapEntry(k, Set<String>.from(v)));
  }
}

