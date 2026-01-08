import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_time_app/services/firebase_service.dart';

/// 증상 선택 기록 데이터 접근 추상화 (날짜 키: yyyy-MM-dd -> 증상 Set)
abstract class SymptomRepository {
  Map<String, Set<String>> loadSelections();
  void saveSelections(Map<String, Set<String>> selections);
  Map<String, String> loadMemos();
  void saveMemo(String dateKey, String memo);
  void deleteMemo(String dateKey);
}

/// 기본 인메모리 구현 (임시 저장 용)
class InMemorySymptomRepository implements SymptomRepository {
  Map<String, Set<String>> _store = {};
  Map<String, String> _memos = {};

  @override
  Map<String, Set<String>> loadSelections() =>
      _store.map((k, v) => MapEntry(k, Set<String>.from(v)));

  @override
  void saveSelections(Map<String, Set<String>> selections) {
    _store = selections.map((k, v) => MapEntry(k, Set<String>.from(v)));
  }

  @override
  Map<String, String> loadMemos() => Map<String, String>.from(_memos);

  @override
  void saveMemo(String dateKey, String memo) {
    if (memo.trim().isEmpty) {
      _memos.remove(dateKey);
    } else {
      _memos[dateKey] = memo;
    }
  }

  @override
  void deleteMemo(String dateKey) {
    _memos.remove(dateKey);
  }
}

/// Firebase 기반 증상 저장소
class FirebaseSymptomRepository implements SymptomRepository {
  final String userId;
  final FirebaseFirestore? _firestore;

  FirebaseSymptomRepository(this.userId)
    : _firestore = FirebaseService.checkInitialized()
          ? FirebaseFirestore.instance
          : null;

  String get _collectionPath => 'users/$userId/symptoms';

  @override
  Map<String, Set<String>> loadSelections() {
    if (_firestore == null) {
      return {};
    }

    // 동기적으로 로드할 수 없으므로 빈 맵 반환
    // 실제로는 비동기 로드가 필요하지만, 기존 인터페이스 유지를 위해
    // 별도의 loadAsync 메서드 제공
    return {};
  }

  /// 비동기 로드
  Future<Map<String, Set<String>>> loadAsync({
    bool forceRefresh = false,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return {};
    }

    try {
      // forceRefresh가 true이면 서버에서 강제로 가져오기
      final snapshot = forceRefresh
          ? await firestore
                .collection(_collectionPath)
                .get(const GetOptions(source: Source.server))
          : await firestore.collection(_collectionPath).get();

      // 컬렉션이 삭제되었거나 비어있으면 빈 Map 반환
      if (snapshot.docs.isEmpty) {
        return {};
      }

      final result = <String, Set<String>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id; // 문서 ID가 날짜 키
        final symptoms =
            (data['symptoms'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toSet() ??
            <String>{};
        result[dateKey] = symptoms;
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  void saveSelections(Map<String, Set<String>> selections) {
    if (_firestore == null) {
      return;
    }

    // 비동기 저장 (Firebase는 비동기만 지원)
    _saveAsync(selections).catchError((error) {
      // 에러 처리
    });
  }

  /// 비동기 저장 (개별 문서 수정/삭제 방식으로 최적화)
  Future<void> _saveAsync(Map<String, Set<String>> selections) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

    try {
      final batch = firestore.batch();
      final collectionRef = firestore.collection(_collectionPath);

      // 기존 문서 조회
      final snapshot = await collectionRef.get();
      final existingKeys = <String>{};
      for (final doc in snapshot.docs) {
        existingKeys.add(doc.id);
      }

      // 삭제: 기존에 있지만 현재 선택에 없는 날짜 (또는 빈 증상)
      for (final existingKey in existingKeys) {
        if (!selections.containsKey(existingKey) ||
            selections[existingKey]?.isEmpty == true) {
          final docRef = collectionRef.doc(existingKey);
          batch.delete(docRef);
        }
      }

      // 추가/수정: 현재 선택된 증상들
      if (selections.isNotEmpty) {
        for (final entry in selections.entries) {
          if (entry.value.isNotEmpty) {
            final docRef = collectionRef.doc(entry.key);
            batch.set(docRef, {
              'symptoms': entry.value.toList(),
              'date': entry.key,
            }, SetOptions(merge: true));
          }
        }
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// 비동기 메모 로드
  Future<Map<String, String>> loadMemosAsync({
    bool forceRefresh = false,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return {};
    }

    try {
      final snapshot = forceRefresh
          ? await firestore
                .collection(_collectionPath)
                .get(const GetOptions(source: Source.server))
          : await firestore.collection(_collectionPath).get();

      if (snapshot.docs.isEmpty) {
        return {};
      }

      final result = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        final memo = data['memo'] as String?;
        if (memo != null && memo.isNotEmpty) {
          result[dateKey] = memo;
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  Map<String, String> loadMemos() {
    // 동기적으로 로드할 수 없으므로 빈 맵 반환
    // 실제로는 비동기 로드가 필요하지만, 기존 인터페이스 유지를 위해
    // 별도의 loadMemosAsync 메서드 제공
    return {};
  }

  @override
  void saveMemo(String dateKey, String memo) {
    if (_firestore == null) {
      return;
    }

    _saveMemoAsync(dateKey, memo).catchError((error) {
      // 에러 처리
    });
  }

  Future<void> _saveMemoAsync(String dateKey, String memo) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

    try {
      final docRef = firestore.collection(_collectionPath).doc(dateKey);
      
      if (memo.trim().isEmpty) {
        // 메모가 비어있으면 memo 필드만 삭제
        await docRef.update({'memo': FieldValue.delete()});
      } else {
        // 메모 저장 (기존 문서가 있으면 merge, 없으면 생성)
        await docRef.set({
          'memo': memo,
          'date': dateKey,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  void deleteMemo(String dateKey) {
    saveMemo(dateKey, '');
  }
}
