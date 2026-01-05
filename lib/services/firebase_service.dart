import 'package:firebase_core/firebase_core.dart';
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
