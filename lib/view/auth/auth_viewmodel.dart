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
    // 로그인 상태 변화 감지 (먼저 설정)
    _authService.authStateChanges.listen((User? user) {
      if (user != null) {
        _currentUser = user;
        _validateAndLoadUser(user)
            .then((_) {
              notifyListeners();
            })
            .catchError((e) {
              debugPrint('authStateChanges 에러: $e');
              notifyListeners();
            });
      } else {
        _currentUser = null;
        _userModel = null;
        notifyListeners();
      }
    });

    // 앱 시작 시 현재 사용자 유효성 검증 (비동기로 실행)
    _validateCurrentUser();
  }

  /// 앱 시작 시 현재 사용자 유효성 검증
  Future<void> _validateCurrentUser() async {
    // 약간의 지연을 두어 authStateChanges 리스너가 먼저 설정되도록 함
    await Future.delayed(const Duration(milliseconds: 100));

    final user = _authService.currentUser;
    if (user != null) {
      await _validateAndLoadUser(user);
      notifyListeners();
    }
  }

  /// 사용자 유효성 검증 및 로드
  Future<void> _validateAndLoadUser(User user) async {
    try {
      await user.reload();
      final updatedUser = _authService.currentUser;
      if (updatedUser == null) {
        await signOut();
        return;
      }

      // 토큰 유효성 확인
      try {
        await updatedUser.getIdToken(true);
      } catch (e) {
        await signOut();
        return;
      }

      // Firestore에서 사용자 정보 확인
      try {
        final userModel = await _authService.getUserFromFirestore(
          updatedUser.uid,
        );
        if (userModel != null) {
          _userModel = userModel;
        } else {
          // 신규 사용자: 기본 정보로 생성
          final newUserModel = UserModel(
            uid: updatedUser.uid,
            email: updatedUser.email ?? '',
            displayName: updatedUser.displayName,
            photoURL: updatedUser.photoURL,
            birthDate: null,
            gender: null,
            phoneNumber: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          // Firestore 저장 시도 (실패해도 기본 정보 유지)
          try {
            await _authService.saveUserToFirestore(newUserModel);
          } catch (_) {
            // 저장 실패 무시
          }
          _userModel = newUserModel;
        }
      } catch (_) {
        // Firestore 조회 실패 시 기본 정보만 사용
        _userModel = UserModel(
          uid: updatedUser.uid,
          email: updatedUser.email ?? '',
          displayName: updatedUser.displayName,
          photoURL: updatedUser.photoURL,
          birthDate: null,
          gender: null,
          phoneNumber: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 검증 에러: $e');
      // 토큰 관련 심각한 에러만 로그아웃
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('token') ||
          errorStr.contains('authentication') ||
          errorStr.contains('unauthorized')) {
        await signOut();
      }
    }
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
      debugPrint('로그인 에러: $e');

      final errorString = e.toString().toLowerCase();
      String errorMsg = '로그인 실패';

      if (errorString.contains('canceled') ||
          errorString.contains('cancelled')) {
        _errorMessage = null;
      } else if (errorString.contains('network') ||
          errorString.contains('connection')) {
        errorMsg = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
      } else if (errorString.contains('apiexception: 10')) {
        errorMsg =
            'Google 로그인 설정 오류가 발생했습니다.\nFirebase Console에서 SHA-1 지문을 확인해주세요.';
      } else {
        errorMsg = '로그인에 실패했습니다. 다시 시도해주세요.';
      }

      _errorMessage = errorMsg;
      _isLoading = false;
      notifyListeners();
      return false;
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
