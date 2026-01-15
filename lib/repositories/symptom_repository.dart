import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:red_time_app/services/firebase_service.dart';

/// 증상 선택 기록 데이터 접근 추상화 (날짜 키: yyyy-MM-dd -> 증상 Set)
abstract class SymptomRepository {
  Map<String, Set<String>> loadSelections();
  void saveSelections(Map<String, Set<String>> selections);
  void saveSymptomForDate(String dateKey, Set<String> symptoms);
  void deleteSymptomDocument(String dateKey);
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
  void saveSymptomForDate(String dateKey, Set<String> symptoms) {
    if (symptoms.isEmpty) {
      _store.remove(dateKey);
    } else {
      _store[dateKey] = Set<String>.from(symptoms);
    }
  }

  @override
  void deleteSymptomDocument(String dateKey) {
    _store.remove(dateKey);
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

/// Firebase 기반 증상 저장소 (월별 문서 구조)
class FirebaseSymptomRepository implements SymptomRepository {
  final String userId;
  final FirebaseFirestore? _firestore;

  FirebaseSymptomRepository(this.userId)
    : _firestore = FirebaseService.checkInitialized()
          ? FirebaseFirestore.instance
          : null;

  String get _collectionPath => 'users/$userId/symptoms';

  /// 날짜 키를 월 키로 변환 (yyyy-MM-dd -> yyyy-MM)
  String _monthKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    // 잘못된 형식이면 현재 월 반환
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Map<String, Set<String>> loadSelections() {
    if (_firestore == null) {
      return {};
    }
    // 동기적으로 로드할 수 없으므로 빈 맵 반환
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
      final result = await loadAllAsync(forceRefresh: forceRefresh);
      return result.symptoms;
    } catch (e) {
      return {};
    }
  }

  /// 증상과 메모를 함께 읽기 (통합 읽기 - 월별 문서에서 읽기)
  Future<({Map<String, Set<String>> symptoms, Map<String, String> memos})>
  loadAllAsync({bool forceRefresh = false}) async {
    final firestore = _firestore;
    if (firestore == null) {
      return (symptoms: <String, Set<String>>{}, memos: <String, String>{});
    }

    try {
      // forceRefresh가 true이면 서버에서 강제로 가져오기
      final snapshot = forceRefresh
          ? await firestore
                .collection(_collectionPath)
                .get(const GetOptions(source: Source.server))
          : await firestore.collection(_collectionPath).get();

      if (snapshot.docs.isEmpty) {
        return (symptoms: <String, Set<String>>{}, memos: <String, String>{});
      }

      final symptomsResult = <String, Set<String>>{};
      final memosResult = <String, String>{};

      // 모든 월 문서를 순회하며 증상과 메모 병합
      for (final doc in snapshot.docs) {
        final data = doc.data();

        // 증상 파싱
        final symptomsMap = data['symptoms'] as Map<String, dynamic>?;
        if (symptomsMap != null) {
          for (final entry in symptomsMap.entries) {
            final dateKey = entry.key;
            final symptomsList = entry.value as List<dynamic>?;
            if (symptomsList != null && symptomsList.isNotEmpty) {
              symptomsResult[dateKey] = symptomsList
                  .map((e) => e as String)
                  .toSet();
            }
          }
        }

        // 메모 파싱
        final memosMap = data['memos'] as Map<String, dynamic>?;
        if (memosMap != null) {
          for (final entry in memosMap.entries) {
            final dateKey = entry.key;
            final memo = entry.value as String?;
            if (memo != null && memo.isNotEmpty) {
              memosResult[dateKey] = memo;
            }
          }
        }
      }

      debugPrint(
        '📖 [Firestore 읽기] 증상+메모 통합 (월별 구조): ${snapshot.docs.length}개 문서 읽기 '
        '(증상: ${symptomsResult.length}개 날짜, 메모: ${memosResult.length}개 날짜)',
      );

      return (symptoms: symptomsResult, memos: memosResult);
    } catch (e) {
      return (symptoms: <String, Set<String>>{}, memos: <String, String>{});
    }
  }

  @override
  void saveSymptomForDate(String dateKey, Set<String> symptoms) {
    if (_firestore == null) {
      return;
    }

    _saveSymptomForDateAsync(dateKey, symptoms).catchError((error) {
      // 에러 처리
    });
  }

  Future<void> _saveSymptomForDateAsync(
    String dateKey,
    Set<String> symptoms,
  ) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

    try {
      final monthKey = _monthKey(dateKey);
      final docRef = firestore.collection(_collectionPath).doc(monthKey);

      // 해당 월 문서 읽기
      final docSnapshot = await docRef.get();
      final data = docSnapshot.data() ?? {};
      final symptomsMap = Map<String, dynamic>.from(
        data['symptoms'] as Map<dynamic, dynamic>? ?? {},
      );
      final memosMap = Map<String, dynamic>.from(
        data['memos'] as Map<dynamic, dynamic>? ?? {},
      );

      // 증상 업데이트
      if (symptoms.isEmpty) {
        symptomsMap.remove(dateKey);
      } else {
        symptomsMap[dateKey] = symptoms.toList();
      }

      // 문서 저장 (증상이 모두 비어있고 메모도 없으면 문서 삭제)
      final hasAnyData = symptomsMap.isNotEmpty || memosMap.isNotEmpty;

      if (!hasAnyData) {
        await docRef.delete();
        debugPrint('🗑️ [Firestore 삭제] 증상 월별 문서: $monthKey');
      } else {
        await docRef.set({
          'symptoms': symptomsMap,
          'memos': memosMap,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));

        debugPrint(
          '💾 [Firestore 쓰기] 증상 월별 문서: $monthKey (날짜: $dateKey, ${symptoms.length}개 증상)',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  void deleteSymptomDocument(String dateKey) {
    saveSymptomForDate(dateKey, <String>{});
  }

  @override
  Map<String, String> loadMemos() {
    // 동기적으로 로드할 수 없으므로 빈 맵 반환
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
      final monthKey = _monthKey(dateKey);
      final docRef = firestore.collection(_collectionPath).doc(monthKey);

      // 해당 월 문서 읽기
      final docSnapshot = await docRef.get();
      final data = docSnapshot.data() ?? {};
      final symptomsMap = Map<String, dynamic>.from(
        data['symptoms'] as Map<dynamic, dynamic>? ?? {},
      );
      final memosMap = Map<String, dynamic>.from(
        data['memos'] as Map<dynamic, dynamic>? ?? {},
      );

      // 메모 업데이트
      if (memo.trim().isEmpty) {
        memosMap.remove(dateKey);
      } else {
        memosMap[dateKey] = memo;
      }

      // 문서 저장 (증상이 모두 비어있고 메모도 없으면 문서 삭제)
      final hasAnyData = symptomsMap.isNotEmpty || memosMap.isNotEmpty;

      if (!hasAnyData) {
        await docRef.delete();
        debugPrint('🗑️ [Firestore 삭제] 메모 월별 문서: $monthKey');
      } else {
        await docRef.set({
          'symptoms': symptomsMap,
          'memos': memosMap,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));

        debugPrint('💾 [Firestore 쓰기] 메모 월별 문서: $monthKey (날짜: $dateKey)');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  void deleteMemo(String dateKey) {
    saveMemo(dateKey, '');
  }

  @override
  void saveSelections(Map<String, Set<String>> selections) {
    // 월별 구조에서는 saveSelections을 사용하지 않음
    // 개별 날짜 저장(saveSymptomForDate)만 사용
  }
}
