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
  Future<List<PeriodCycle>> loadAsync() async {
    final firestore = _firestore;
    if (firestore == null) {
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
      return [];
    }
  }

  @override
  void save(List<PeriodCycle> cycles) {
    if (_firestore == null) {
      return;
    }

    // 비동기 저장 (Firebase는 비동기만 지원)
    _saveAsync(cycles).catchError((error) {
      // 에러 처리
    });
  }

  /// 비동기 저장 (개별 문서 수정/삭제 방식으로 최적화)
  Future<void> _saveAsync(List<PeriodCycle> cycles) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

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
      if (cycles.isNotEmpty) {
        for (final cycle in cycles) {
          final startKey = _dateKey(cycle.start);
          final docRef = existingDocs.containsKey(startKey)
              ? existingDocs[startKey]!.reference
              : collectionRef.doc(startKey);

          batch.set(docRef, {
            'start': cycle.start.toIso8601String(),
            if (cycle.end != null) 'end': cycle.end!.toIso8601String(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// 날짜를 키로 변환 (yyyy-MM-dd)
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
