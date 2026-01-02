import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/services/firebase_service.dart';

/// 생리 주기 데이터 접근 추상화 (향후 Local/Firebase 구현 교체 용이)
abstract class PeriodRepository {
  List<PeriodCycle> load();
  void save(List<PeriodCycle> cycles);
}

/// 기본 인메모리 구현 (임시 저장 용)
class InMemoryPeriodRepository implements PeriodRepository {
  List<PeriodCycle> _store = [];

  @override
  List<PeriodCycle> load() => List<PeriodCycle>.from(_store);

  @override
  void save(List<PeriodCycle> cycles) {
    print(
      '⚠️ [InMemoryPeriodRepository] save() 호출됨 - 메모리에만 저장 (Firebase 저장 안됨)',
    );
    print('⚠️ [InMemoryPeriodRepository] 주기 개수: ${cycles.length}');
    _store = List<PeriodCycle>.from(cycles);
  }
}

/// Firebase 기반 생리 주기 저장소
class FirebasePeriodRepository implements PeriodRepository {
  final String userId;
  final FirebaseFirestore? _firestore;

  FirebasePeriodRepository(this.userId)
    : _firestore = FirebaseService.checkInitialized()
          ? FirebaseFirestore.instance
          : null {
    print('📝 [FirebasePeriodRepository] 사용자 ID: $userId');
    print('📝 [FirebasePeriodRepository] 저장 경로: users/$userId/periodCycles');
  }

  String get _collectionPath => 'users/$userId/periodCycles';

  @override
  List<PeriodCycle> load() {
    if (_firestore == null) {
      print('⚠️ [FirebasePeriodRepository] Firestore가 초기화되지 않았습니다.');
      return [];
    }

    try {
      // 동기적으로 로드할 수 없으므로 빈 리스트 반환
      // 실제로는 비동기 로드가 필요하지만, 기존 인터페이스 유지를 위해
      // 별도의 loadAsync 메서드 제공
      return [];
    } catch (e) {
      print('❌ [FirebasePeriodRepository] 로드 오류: $e');
      return [];
    }
  }

  /// 비동기 로드
  Future<List<PeriodCycle>> loadAsync() async {
    final firestore = _firestore;
    if (firestore == null) {
      print('⚠️ [FirebasePeriodRepository] Firestore가 초기화되지 않았습니다.');
      return [];
    }

    try {
      final snapshot = await firestore.collection(_collectionPath).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PeriodCycle(
          DateTime.parse(data['start'] as String),
          data['end'] != null ? DateTime.parse(data['end'] as String) : null,
        );
      }).toList()..sort((a, b) => a.start.compareTo(b.start));
    } catch (e) {
      print('❌ [FirebasePeriodRepository] 비동기 로드 오류: $e');
      return [];
    }
  }

  @override
  void save(List<PeriodCycle> cycles) {
    print('💾 [FirebasePeriodRepository] save() 호출됨 - 주기 개수: ${cycles.length}');
    if (_firestore == null) {
      print('⚠️ [FirebasePeriodRepository] Firestore가 초기화되지 않았습니다.');
      return;
    }

    // 비동기 저장 (Firebase는 비동기만 지원)
    _saveAsync(cycles).catchError((error) {
      print('❌ [FirebasePeriodRepository] 저장 중 에러 발생: $error');
      print('❌ [FirebasePeriodRepository] Stack trace: ${StackTrace.current}');
    });
  }

  /// 비동기 저장 (개별 문서 수정/삭제 방식으로 최적화)
  Future<void> _saveAsync(List<PeriodCycle> cycles) async {
    final firestore = _firestore;
    if (firestore == null) {
      print('⚠️ [FirebasePeriodRepository] _saveAsync: Firestore가 null입니다.');
      return;
    }

    print('💾 [FirebasePeriodRepository] _saveAsync 시작 - 경로: $_collectionPath');
    print('💾 [FirebasePeriodRepository] 저장할 주기 개수: ${cycles.length}');

    try {
      final batch = firestore.batch();
      final collectionRef = firestore.collection(_collectionPath);

      // 기존 문서 조회
      final snapshot = await collectionRef.get();
      final existingDocs = <String, DocumentSnapshot>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final startKey = _dateKey(DateTime.parse(data['start'] as String));
        existingDocs[startKey] = doc;
      }

      // 현재 주기들의 시작일 키 생성
      final currentKeys = <String>{};
      for (final cycle in cycles) {
        final startKey = _dateKey(cycle.start);
        currentKeys.add(startKey);
      }

      // 삭제: 기존에 있지만 현재 리스트에 없는 주기
      for (final entry in existingDocs.entries) {
        if (!currentKeys.contains(entry.key)) {
          batch.delete(entry.value.reference);
        }
      }

      // 추가/수정: 현재 리스트의 주기들
      if (cycles.isEmpty) {
        print('ℹ️ [FirebasePeriodRepository] 저장할 주기가 없습니다. 기존 데이터만 삭제합니다.');
      } else {
        for (final cycle in cycles) {
          final startKey = _dateKey(cycle.start);
          final docRef = existingDocs.containsKey(startKey)
              ? existingDocs[startKey]!.reference
              : collectionRef.doc(startKey);

          print(
            '💾 [FirebasePeriodRepository] 주기 저장: $startKey (시작: ${cycle.start.toIso8601String()}, 종료: ${cycle.end?.toIso8601String() ?? "없음"})',
          );
          batch.set(docRef, {
            'start': cycle.start.toIso8601String(),
            if (cycle.end != null) 'end': cycle.end!.toIso8601String(),
          });
        }
      }

      print('💾 [FirebasePeriodRepository] Batch 커밋 시작...');
      await batch.commit();
      final added = cycles.isEmpty ? 0 : cycles.length - existingDocs.length;
      final deleted = existingDocs.length - currentKeys.length;
      print(
        '✅ [FirebasePeriodRepository] 생리 주기 저장 완료: 총 ${cycles.length}개 (추가: $added, 수정: ${cycles.isEmpty ? 0 : cycles.length - added - deleted}, 삭제: $deleted)',
      );
      print('✅ [FirebasePeriodRepository] 저장 경로: $_collectionPath');
    } catch (e, stackTrace) {
      print('❌ [FirebasePeriodRepository] 저장 오류: $e');
      print('❌ [FirebasePeriodRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 날짜를 키로 변환 (yyyy-MM-dd)
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
