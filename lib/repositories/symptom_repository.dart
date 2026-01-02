import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_time_app/services/firebase_service.dart';

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

/// Firebase 기반 증상 저장소
class FirebaseSymptomRepository implements SymptomRepository {
  final String userId;
  final FirebaseFirestore? _firestore;

  FirebaseSymptomRepository(this.userId)
    : _firestore = FirebaseService.checkInitialized()
          ? FirebaseFirestore.instance
          : null {
    print('📝 [FirebaseSymptomRepository] 사용자 ID: $userId');
    print('📝 [FirebaseSymptomRepository] 저장 경로: users/$userId/symptoms');
  }

  String get _collectionPath => 'users/$userId/symptoms';

  @override
  Map<String, Set<String>> loadSelections() {
    if (_firestore == null) {
      print('⚠️ [FirebaseSymptomRepository] Firestore가 초기화되지 않았습니다.');
      return {};
    }

    // 동기적으로 로드할 수 없으므로 빈 맵 반환
    // 실제로는 비동기 로드가 필요하지만, 기존 인터페이스 유지를 위해
    // 별도의 loadAsync 메서드 제공
    return {};
  }

  /// 비동기 로드
  Future<Map<String, Set<String>>> loadAsync() async {
    final firestore = _firestore;
    if (firestore == null) {
      print('⚠️ [FirebaseSymptomRepository] Firestore가 초기화되지 않았습니다.');
      return {};
    }

    try {
      final snapshot = await firestore.collection(_collectionPath).get();
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
      print('❌ [FirebaseSymptomRepository] 비동기 로드 오류: $e');
      return {};
    }
  }

  @override
  void saveSelections(Map<String, Set<String>> selections) {
    print(
      '💾 [FirebaseSymptomRepository] saveSelections() 호출됨 - 날짜 개수: ${selections.length}',
    );
    if (_firestore == null) {
      print('⚠️ [FirebaseSymptomRepository] Firestore가 초기화되지 않았습니다.');
      return;
    }

    // 비동기 저장 (Firebase는 비동기만 지원)
    _saveAsync(selections).catchError((error) {
      print('❌ [FirebaseSymptomRepository] 저장 중 에러 발생: $error');
      print('❌ [FirebaseSymptomRepository] Stack trace: ${StackTrace.current}');
    });
  }

  /// 비동기 저장 (개별 문서 수정/삭제 방식으로 최적화)
  Future<void> _saveAsync(Map<String, Set<String>> selections) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('⚠️ [FirebaseSymptomRepository] _saveAsync: Firestore가 null입니다.');
      return;
    }

    print(
      '💾 [FirebaseSymptomRepository] _saveAsync 시작 - 경로: $_collectionPath',
    );
    print('💾 [FirebaseSymptomRepository] 저장할 날짜 개수: ${selections.length}');

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
      if (selections.isEmpty) {
        print('ℹ️ [FirebaseSymptomRepository] 저장할 증상 기록이 없습니다. 기존 데이터만 삭제합니다.');
      } else {
        for (final entry in selections.entries) {
          if (entry.value.isNotEmpty) {
            final docRef = collectionRef.doc(entry.key);
            print(
              '💾 [FirebaseSymptomRepository] 증상 저장: ${entry.key} - ${entry.value.toList()}',
            );
            batch.set(docRef, {
              'symptoms': entry.value.toList(),
              'date': entry.key,
            });
          }
        }
      }

      print('💾 [FirebaseSymptomRepository] Batch 커밋 시작...');
      await batch.commit();
      final added = selections.keys
          .where((k) => !existingKeys.contains(k))
          .length;
      final deleted = existingKeys
          .where(
            (k) => !selections.containsKey(k) || selections[k]?.isEmpty == true,
          )
          .length;
      print(
        '✅ [FirebaseSymptomRepository] 증상 기록 저장 완료: 총 ${selections.length}개 (추가: $added, 수정: ${selections.length - added - deleted}, 삭제: $deleted)',
      );
      print('✅ [FirebaseSymptomRepository] 저장 경로: $_collectionPath');
    } catch (e, stackTrace) {
      print('❌ [FirebaseSymptomRepository] 저장 오류: $e');
      print('❌ [FirebaseSymptomRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
