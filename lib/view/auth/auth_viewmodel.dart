import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/services/auth_service.dart';

/// 인증 상태 관리 뷰모델
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthViewModel() {
    // 로그인 상태 변화 감지
    _authService.authStateChanges.listen((User? user) {
      _currentUser = user;
      if (user != null) {
        _loadUserModel(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// 구글 로그인
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final userModel = await _authService.signInWithGoogle();
      if (userModel != null) {
        _userModel = userModel;
        _currentUser = _authService.currentUser;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // 에러 메시지 상세화
      String errorMsg = '로그인 실패';
      if (e.toString().contains('network_error') ||
          e.toString().contains('network')) {
        errorMsg = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
      } else if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('canceled')) {
        errorMsg = '로그인이 취소되었습니다.';
      } else if (e.toString().contains('sign_in_failed') ||
          e.toString().contains('authentication')) {
        errorMsg = '인증에 실패했습니다. 다시 시도해주세요.';
      } else if (e.toString().contains('firebase')) {
        errorMsg = 'Firebase 연결 오류가 발생했습니다.';
      } else {
        errorMsg = '로그인 실패: ${e.toString()}';
      }
      _errorMessage = errorMsg;
      _isLoading = false;
      notifyListeners();
      print('구글 로그인 상세 오류: $e');
      return false;
    }
  }

  /// Firestore에서 사용자 정보 로드
  Future<void> _loadUserModel(String uid) async {
    try {
      _userModel = await _authService.getUserFromFirestore(uid);
      notifyListeners();
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      _currentUser = null;
      _userModel = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '로그아웃 실패: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }
}
