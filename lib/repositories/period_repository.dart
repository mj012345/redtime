import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    // Offline Persistence: 네트워크 오류는 자동으로 로컬 캐시에 저장되고 자동 동기화
    // 권한 오류(permission-denied)만 별도 처리
    _saveAsync(cycles, deleteStartDates: deleteStartDates).catchError((error) {
      if (error is FirebaseException) {
        // 권한 오류만 처리
        if (error.code == 'permission-denied') {
          // 권한 오류는 사용자 데이터 동기화 실패일 가능성이 높음
        }
      }
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

      // 삭제할 주기가 있는 경우 해당 년도 문서에서 제거
      if (deleteStartDates != null && deleteStartDates.isNotEmpty) {
        // 삭제할 시작일의 년도별 그룹화
        final deleteDatesByYear = <String, Set<String>>{};
        for (final dateKey in deleteStartDates) {
          // dateKey는 yyyy-MM-dd 형식
          final parts = dateKey.split('-');
          if (parts.isNotEmpty) {
            final yearKey = parts[0];
            deleteDatesByYear
                .putIfAbsent(yearKey, () => <String>{})
                .add(dateKey);
          }
        }

        // 각 년도 문서를 읽어서 삭제할 주기 제거
        for (final entry in deleteDatesByYear.entries) {
          final yearKey = entry.key;
          final deleteDates = entry.value;
          final docRef = collectionRef.doc(yearKey);

          try {
            // 기존 문서 읽기
            final docSnapshot = await docRef.get();
            if (docSnapshot.exists) {
              final data = docSnapshot.data() ?? {};
              final cyclesList = (data['cycles'] as List<dynamic>?) ?? [];

              // 삭제할 주기 제외한 새로운 리스트 생성
              final filteredCycles = cyclesList.where((cycleData) {
                final cycleMap = cycleData as Map<String, dynamic>;
                final start = DateTime.parse(cycleMap['start'] as String);
                final startKey =
                    '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
                return !deleteDates.contains(startKey);
              }).toList();

              if (filteredCycles.isEmpty) {
                // 모든 주기가 삭제되면 문서 삭제
                batch.delete(docRef);
              } else {
                // 필터링된 주기로 문서 업데이트
                batch.set(docRef, {
                  'cycles': filteredCycles,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: false));
              }
            }
          } catch (e) {
            // 문서 읽기 실패 시 무시 (존재하지 않는 문서일 수 있음)
          }
        }
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

      // 모든 주기가 삭제된 경우 모든 문서 삭제
      if (cycles.isEmpty &&
          (deleteStartDates == null || deleteStartDates.isEmpty)) {
        // 기존 모든 문서 조회하여 삭제
        try {
          final snapshot = await collectionRef.get();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
        } catch (e) {
          // 조회 실패 시 무시
        }
      }

      // 빈 batch는 commit하지 않음 (Security Rules 검증 불필요)
      // writeCount > 0이거나 삭제 작업이 있으면 commit
      if (writeCount > 0 ||
          (deleteStartDates != null && deleteStartDates.isNotEmpty) ||
          cycles.isEmpty) {
        // Offline Persistence: 네트워크 오류 시에도 로컬 캐시에 저장
        // 네트워크 복구 시 자동으로 서버에 동기화됨
        await batch.commit();
      } else {
        return;
      }
    } catch (e) {
      // 권한 오류(permission-denied)만 재throw
      // 네트워크 오류는 Offline Persistence가 자동 처리하므로 무시
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          rethrow; // 권한 오류는 상위로 전파
        }
        // 네트워크 오류 등은 Offline Persistence가 처리하므로 무시
      } else {
        // FirebaseException이 아닌 다른 예외는 재throw
        rethrow;
      }
    }
  }
}
