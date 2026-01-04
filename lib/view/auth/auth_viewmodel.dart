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
              // 에러 로깅 (디버깅용)
              debugPrint('authStateChanges 리스너 에러: $e');
              // 에러가 발생해도 로그아웃하지 않고 현재 상태 유지
              // (로그인은 성공했지만 추가 정보 로드 실패인 경우)
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

      // Firestore에서 사용자 정보 확인
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
          // Firestore에 저장 시도
          try {
            await _authService.saveUserToFirestore(newUserModel);
            _userModel = newUserModel;
          } catch (saveError) {
            // 저장 실패해도 기본 정보는 설정 (나중에 재시도 가능)
            debugPrint('Firestore 사용자 정보 저장 실패: $saveError');
            _userModel = newUserModel;
          }
        } else {
          _userModel = userModel;
        }
      } catch (e) {
        // Firestore 조회 실패 시에도 기본 사용자 정보는 유지
        debugPrint('Firestore 사용자 정보 조회 실패: $e');
        // 기본 UserModel 생성
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
      // 심각한 에러(토큰 무효 등)만 로그아웃
      debugPrint('사용자 검증 중 심각한 에러: $e');
      // 토큰 관련 에러가 아닌 경우 로그아웃하지 않음
      if (e.toString().contains('token') ||
          e.toString().contains('authentication') ||
          e.toString().contains('unauthorized')) {
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
      // 에러 로깅 (디버깅용)
      debugPrint('로그인 에러: $e');
      debugPrint('에러 타입: ${e.runtimeType}');

      // 에러 메시지 상세화
      String errorMsg = '로그인 실패';
      final errorString = e.toString().toLowerCase();

      if (errorString.contains('network_error') ||
          errorString.contains('network') ||
          errorString.contains('socket') ||
          errorString.contains('connection')) {
        errorMsg = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
      } else if (errorString.contains('sign_in_canceled') ||
          errorString.contains('canceled') ||
          errorString.contains('cancelled')) {
        errorMsg = '로그인이 취소되었습니다.';
        // 취소는 에러가 아니므로 에러 메시지 없이 반환
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return false;
      } else if (errorString.contains('sign_in_failed') ||
          errorString.contains('authentication') ||
          errorString.contains('auth') ||
          errorString.contains('credential') ||
          errorString.contains('invalid')) {
        errorMsg = '인증에 실패했습니다. 다시 시도해주세요.';
      } else if (errorString.contains('firebase')) {
        errorMsg = 'Firebase 연결 오류가 발생했습니다.';
      } else if (errorString.contains('token')) {
        errorMsg = '인증 토큰 오류가 발생했습니다. 다시 시도해주세요.';
      } else {
        // 자세한 에러 메시지 표시 (개발 중)
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
