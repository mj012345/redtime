import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:red_time_app/models/period_cycle.dart';
import 'package:red_time_app/services/firebase_service.dart';

/// 생리 주기 데이터 접근 추상화 (향후 Local/Firebase 구현 교체 용이)
abstract class PeriodRepository {
  List<PeriodCycle> load();
  void save(List<PeriodCycle> cycles, {Set<String>? deleteStartDates});
}

/// 기본 인메모리 구현 (임시 저장 용)
class InMemoryPeriodRepository implements PeriodRepository {
  List<PeriodCycle> _store = [];

  @override
  List<PeriodCycle> load() => List<PeriodCycle>.from(_store);

  @override
  void save(List<PeriodCycle> cycles, {Set<String>? deleteStartDates}) {
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
          : null;

  String get _collectionPath => 'users/$userId/periodCycles';

  @override
  List<PeriodCycle> load() {
    if (_firestore == null) {
      return [];
    }

    try {
      // 동기적으로 로드할 수 없으므로 빈 리스트 반환
      // 실제로는 비동기 로드가 필요하지만, 기존 인터페이스 유지를 위해
      // 별도의 loadAsync 메서드 제공
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 비동기 로드
  Future<List<PeriodCycle>> loadAsync({bool forceRefresh = false}) async {
    final firestore = _firestore;
    if (firestore == null) {
      return [];
    }

    try {
      // forceRefresh가 true이면 서버에서 강제로 가져오기
      final snapshot = forceRefresh
          ? await firestore
                .collection(_collectionPath)
                .get(const GetOptions(source: Source.server))
          : await firestore.collection(_collectionPath).get();
      final cycles = snapshot.docs.map((doc) {
        final data = doc.data();
        return PeriodCycle(
          DateTime.parse(data['start'] as String),
          data['end'] != null ? DateTime.parse(data['end'] as String) : null,
        );
      }).toList()..sort((a, b) => a.start.compareTo(b.start));

      debugPrint(
        '📖 [Firestore 읽기] 생리 주기: ${snapshot.docs.length}개 문서 읽기 '
        '(주기: ${cycles.length}개)',
      );

      return cycles;
    } catch (e) {
      return [];
    }
  }

  @override
  void save(List<PeriodCycle> cycles, {Set<String>? deleteStartDates}) {
    if (_firestore == null) {
      return;
    }

    // 비동기 저장 (Firebase는 비동기만 지원)
    _saveAsync(cycles, deleteStartDates: deleteStartDates).catchError((error) {
      // 에러 처리
    });
  }

  /// 비동기 저장 (메모리 추적 기반 - 삭제할 시작일만 전달)
  Future<void> _saveAsync(
    List<PeriodCycle> cycles, {
    Set<String>? deleteStartDates,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

    try {
      final batch = firestore.batch();
      final collectionRef = firestore.collection(_collectionPath);

      // 삭제: 메모리 추적으로 전달된 시작일 문서 삭제
      int deleteCount = 0;
      if (deleteStartDates != null && deleteStartDates.isNotEmpty) {
        for (final startKey in deleteStartDates) {
          final docRef = collectionRef.doc(startKey);
          batch.delete(docRef);
          deleteCount++;
        }
      }

      // 추가/수정: 현재 리스트의 주기들
      int writeCount = 0;
      if (cycles.isNotEmpty) {
        for (final cycle in cycles) {
          final startKey = _dateKey(cycle.start);
          final docRef = collectionRef.doc(startKey);

          batch.set(docRef, {
            'start': cycle.start.toIso8601String(),
            if (cycle.end != null) 'end': cycle.end!.toIso8601String(),
          });
          writeCount++;
        }
      }

      await batch.commit();

      debugPrint(
        '📦 [Firestore 배치 작업] 생리 주기 저장: '
        '읽기 0개, 쓰기 $writeCount개, 삭제 $deleteCount개',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 날짜를 키로 변환 (yyyy-MM-dd)
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
