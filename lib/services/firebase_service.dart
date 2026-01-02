import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase 초기화 상태 관리
class FirebaseService {
  static bool _isInitialized = false;
  static String? _errorMessage;

  static bool get isInitialized => _isInitialized;
  static String? get errorMessage => _errorMessage;

  /// Firebase 초기화
  static Future<bool> initialize() async {
    try {
      print('🔵 [FirebaseService] Firebase 초기화 시작...');
      print('🔵 [FirebaseService] Platform: ${defaultTargetPlatform}');

      await Firebase.initializeApp();

      // 초기화 후 확인
      try {
        final app = Firebase.app();
        print('✅ [FirebaseService] Firebase 초기화 성공! App name: ${app.name}');
        _isInitialized = true;
        _errorMessage = null;
        return true;
      } catch (e) {
        print('❌ [FirebaseService] Firebase.app() 확인 실패: $e');
        _isInitialized = false;
        _errorMessage = e.toString();
        return false;
      }
    } catch (e, stackTrace) {
      _isInitialized = false;
      _errorMessage = e.toString();
      print('❌ [FirebaseService] Firebase 초기화 오류: $e');
      print('❌ [FirebaseService] Stack trace: $stackTrace');
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
      print('❌ [FirebaseService] checkInitialized 실패: $e');
      return false;
    }
  }
}
