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

/// Firebase 기반 생리 주기 저장소 (년도별 문서 구조)
class FirebasePeriodRepository implements PeriodRepository {
  final String userId;
  final FirebaseFirestore? _firestore;

  FirebasePeriodRepository(this.userId)
    : _firestore = FirebaseService.checkInitialized()
          ? FirebaseFirestore.instance
          : null;

  String get _collectionPath => 'users/$userId/periodCycles';

  /// 날짜에서 년도 키 추출 (yyyy-MM-dd -> yyyy)
  String _yearKey(DateTime date) {
    return date.year.toString().padLeft(4, '0');
  }

  @override
  List<PeriodCycle> load() {
    if (_firestore == null) {
      return [];
    }

    try {
      // 동기적으로 로드할 수 없으므로 빈 리스트 반환
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 비동기 로드 (년도별 문서에서 읽기)
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

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final allCycles = <PeriodCycle>[];

      // 모든 년도 문서를 순회하며 주기 병합
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cyclesList = data['cycles'] as List<dynamic>?;
        if (cyclesList != null) {
          for (final cycleData in cyclesList) {
            final cycleMap = cycleData as Map<String, dynamic>;
            final start = DateTime.parse(cycleMap['start'] as String);
            final endStr = cycleMap['end'] as String?;
            final end = endStr != null ? DateTime.parse(endStr) : null;
            allCycles.add(PeriodCycle(start, end));
          }
        }
      }

      // 날짜순 정렬
      allCycles.sort((a, b) => a.start.compareTo(b.start));

      debugPrint(
        '📖 [Firestore 읽기] 생리 주기 (년도별 구조): ${snapshot.docs.length}개 문서 읽기 '
        '(주기: ${allCycles.length}개)',
      );

      return allCycles;
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

  /// 비동기 저장 (년도별 문서 구조)
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

      // 년도별로 주기 그룹화
      final cyclesByYear = <String, List<PeriodCycle>>{};
      for (final cycle in cycles) {
        final yearKey = _yearKey(cycle.start);
        cyclesByYear.putIfAbsent(yearKey, () => []).add(cycle);
      }

      // 각 년도 문서에 저장
      int writeCount = 0;
      for (final entry in cyclesByYear.entries) {
        final yearKey = entry.key;
        final yearCycles = entry.value;
        final docRef = collectionRef.doc(yearKey);

        // 주기 데이터 변환
        final cyclesData = yearCycles.map((cycle) {
          return {
            'start': cycle.start.toIso8601String(),
            if (cycle.end != null) 'end': cycle.end!.toIso8601String(),
          };
        }).toList();

        batch.set(docRef, {
          'cycles': cyclesData,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
        writeCount++;
      }

      // 삭제할 시작일이 있는 경우 (기존 구조와의 호환을 위해 유지)
      // 년도별 구조에서는 deleteStartDates를 직접 처리하기 어려우므로
      // 전체 년도 문서를 다시 저장하는 방식으로 처리
      // (deleteStartDates가 있으면 해당 년도의 문서를 다시 읽어서 처리 필요)
      // 하지만 현재 구조에서는 모든 주기를 다시 저장하므로 자동으로 처리됨

      await batch.commit();

      debugPrint(
        '📦 [Firestore 배치 작업] 생리 주기 저장 (년도별 구조): '
        '읽기 0개, 쓰기 $writeCount개, 삭제 0개',
      );
    } catch (e) {
      rethrow;
    }
  }
}
