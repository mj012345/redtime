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
      // 사용자 정보 갱신 (Firebase에서 삭제되었는지 확인)
      await user.reload();

      // 갱신된 사용자 정보 가져오기
      final updatedUser = _authService.currentUser;
      if (updatedUser == null) {
        await signOut();
        return;
      }

      // 토큰 유효성 확인
      try {
        await updatedUser.getIdToken(true); // 강제 갱신
      } catch (e) {
        await signOut();
        return;
      }

      // Firestore에서 사용자 정보 확인 (권한 오류 발생 시 로그인 실패)
      try {
        final userModel = await _authService.getUserFromFirestore(
          updatedUser.uid,
        );
        if (userModel == null) {
          // Firestore에 사용자 정보가 없으면 새로 생성
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
          // Firestore에 저장 시도 (권한 오류 발생 시 예외 발생)
          await _authService.saveUserToFirestore(newUserModel);
          _userModel = newUserModel;
        } else {
          _userModel = userModel;
        }
      } catch (e) {
        // Firestore 권한 오류 발생 시 로그인 실패
        await signOut();
        return;
      }

      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      // 에러 발생 시 로그아웃 처리
      await signOut();
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
