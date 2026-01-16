import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:red_time_app/firebase_options.dart';

/// Firebase 초기화 상태 관리
class FirebaseService {
  static bool _isInitialized = false;
  static String? _errorMessage;

  static bool get isInitialized => _isInitialized;
  static String? get errorMessage => _errorMessage;

  /// Firebase 초기화
  static Future<bool> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 초기화 후 확인
      try {
        Firebase.app();
        _isInitialized = true;
        _errorMessage = null;

        // Firestore Offline Persistence 활성화
        await _enableOfflinePersistence();

        return true;
      } catch (e) {
        _isInitialized = false;
        _errorMessage = e.toString();
        return false;
      }
    } catch (e) {
      _isInitialized = false;
      _errorMessage = e.toString();
      return false;
    }
  }

  /// Firestore Offline Persistence 활성화
  /// 네트워크 오류 시에도 로컬 캐시에 저장하고, 네트워크 복구 시 자동 동기화
  static Future<void> _enableOfflinePersistence() async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Offline Persistence는 기본적으로 활성화되어 있지만, Settings로 명시적 설정
      // persistenceEnabled: true는 기본값이지만 명시적으로 설정
      firestore.settings = const Settings(
        persistenceEnabled: true, // 오프라인 영속성 활성화
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // 캐시 크기 무제한
      );
    } catch (e) {
      // 이미 초기화된 경우 등 에러 무시 (기본적으로 활성화되어 있음)
    }
  }

  /// Firebase 앱 인스턴스 확인
  static bool checkInitialized() {
    try {
      Firebase.app();
      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      _errorMessage = e.toString();
      return false;
    }
  }
}
