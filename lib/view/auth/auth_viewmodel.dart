import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/services/auth_service.dart';
import 'package:red_time_app/constants/terms_version.dart';
import 'package:red_time_app/view/auth/auth_state.dart';

export 'package:red_time_app/view/auth/auth_state.dart';

/// 인증 상태 관리 뷰모델 (State-Driven Approach)
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authStateSubscription;

  // 단일 상태 관리
  AuthState _state = const AuthUninitialized();
  AuthState get state => _state;

  AuthViewModel();

  // Convenience getters for UI compatibility and helpers
  User? get currentUser {
    final s = _state;
    return s is Authenticated ? s.user : null;
  }

  UserModel? get userModel {
    final s = _state;
    return s is Authenticated ? s.userModel : null;
  }

  bool get isAuthenticated => _state is Authenticated;

  String? get errorMessage {
    final s = _state;
    return s is AuthError ? s.message : null;
  }

  // 수동 로그인 로딩 상태 (로그인 버튼 스피너용)
  bool _isManualLoading = false;
  bool get isManualLoading => _isManualLoading;

  void initialize() {
    // 이미 초기화 상태가 아니면 리턴 (중복 호출 방지)
    if (_state is! AuthUninitialized && _state is! AuthError) return;

    // 앱 시작 시 초기 상태 (이미 AuthUninitialized이지만 명시적 호출)
    if (_state is! AuthUninitialized) {
       _state = const AuthUninitialized();
       notifyListeners();
    }

    // Firebase Auth 상태 리스너 등록
    _authStateSubscription?.cancel(); // 기존 구독 취소 안전장치
    _authStateSubscription = _authService.authStateChanges.listen((User? user) {
      if (user == null) {
        // 이미 로그아웃 상태라면 중복 처리 방지
        if (_state is! Unauthenticated) {
          _state = const Unauthenticated();
          _isManualLoading = false;
          notifyListeners();
        }
      } else {
        // 이미 인증된 상태에서 동일 유저라면 중복 로딩 방지 (Token refresh 등 무시)
        final currentState = _state;
        if (currentState is Authenticated && currentState.user.uid == user.uid) {
          return;
        }

        // 로그인 감지 -> 데이터 로딩 시작
        _loadUser(user);
      }
    });
    
    // 별도 _validateCurrentUser 호출 불필요: authStateChanges가 초기 값도 전달해줌
  }

  /// 초기화 재시도 (네트워크 오류 등으로 실패 시 외부에서 호출)
  void retryInitialization() {
     initialize();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  /// 사용자 데이터 로드 로직 (Atomic Transaction)
  Future<void> _loadUser(User user) async {
    // 이미 로딩 중이면 중복 호출 방지 (선택 사항)
    if (_state is AuthLoading && _state is! AuthUninitialized) {
        return;
    }

    // UI에 로딩 표시
    // 앱 초기화 상태(스플래시)나 이미 로딩 상태일 때만 AuthLoading(스플래시) 유지
    // 로그인 화면(Unauthenticated)에서 왔다면, 로그인 버튼 스피너(_isManualLoading)만 유지하고 스플래시로 전환하지 않음
    if (_state is AuthUninitialized || _state is AuthLoading) {
      if (_state is! AuthLoading) {
        _state = const AuthLoading();
        notifyListeners();
      }
    } else {
      // 수동 로그인 진행 중 (이미 true일 수 있음)
      if (!_isManualLoading) {
        _isManualLoading = true;
        notifyListeners();
      }
    }

    try {
      // 1. User Reload & Token Check
      try {
        await user.reload();
      } catch (e) {
         // ignore
      }
      
      final updatedUser = _authService.currentUser;
      if (updatedUser == null) {
        throw Exception('사용자를 찾을 수 없습니다.');
      }

      // 토큰 갱신 시도
      try {
        await updatedUser.getIdToken(true);
      } catch (e) {
        await _authService.signOut();
        _state = const Unauthenticated();
        notifyListeners();
        return;
      }

      // 2. Firestore 데이터 로드
      UserModel? userModel = await _loadUserDataWithRetry(updatedUser.uid);

      if (userModel == null) {
        // 신규 유저로 간주 (약관 동의 전) -> 로컬 모델 생성
        userModel = UserModel(
          uid: updatedUser.uid,
          email: updatedUser.email ?? '',
          displayName: null,
          photoURL: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 신규 유저는 Authenticated 상태지만 isNewUser = true
        _state = Authenticated(updatedUser, userModel, isNewUser: true);
      } else {
        // 기존 유저
        _state = Authenticated(updatedUser, userModel, isNewUser: false);
      }
      notifyListeners();
      _isManualLoading = false;

    } catch (e) {
      // 에러 발생 시 로그아웃 처리하여 불일치 방지
      await _authService.signOut();

      String msg = '초기화 중 오류가 발생했습니다.';
      if (e is FirebaseAuthException) {
        msg = e.message ?? msg;
      }
      _state = AuthError(msg);
      _isManualLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> _loadUserDataWithRetry(String uid, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        // 타임아웃을 넉넉히 줌
        final model = await _authService.getUserFromFirestore(uid).timeout(
          Duration(seconds: 5 + i * 2),
        );
        return model;
      } catch (e) {
        if (i == maxRetries - 1) {
           // 마지막 시도 실패. 
           // 여기서는 null을 리턴하여 '신규 유저' 경로를 타게 할지, 
           // 아니면 에러를 던져서 'AuthError'로 가게 할지 정책 결정 필요.
           // 오프라인 퍼스트 앱이므로, 캐시도 없고 네트워크도 안되면 에러가 맞음.
           // 다만 기존 코드에서는 null을 리턴하고 있었음.
           return null; 
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }
    return null;
  }

  /// 구글 로그인 액션
  Future<bool> signInWithGoogle() async {
    // 상태를 AuthLoading으로 바꾸지 않고, 내부 플래그만 변경
    // _state = const AuthLoading(); // 제거
    _isManualLoading = true;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        // 취소됨 -> 로그아웃 상태로 복귀
        _state = const Unauthenticated();
        _isManualLoading = false;
        notifyListeners();
        return false;
      }

      // 성공하면 authStateChanges 리스너가 감지하여 _loadUser를 호출함.
      return true;

    } catch (e) {
      String msg = '로그인에 실패했습니다.';
      if (e is FirebaseAuthException) {
        msg = e.message ?? msg;
      }
      _state = AuthError(msg);
      notifyListeners();
      return false;
    }
  }

  /// 로그아웃 액션
  Future<void> signOut() async {
    _state = const AuthLoading();
    _isManualLoading = false;
    notifyListeners();

    try {
      await _authService.signOut();
      // 리스너가 Unauthenticated로 변경함
    } catch (e) {
      _state = AuthError('로그아웃 실패: $e');
      notifyListeners();
    }
  }

  /// 회원 탈퇴 액션
  Future<bool> deleteAccount() async {
    _state = const AuthLoading();
    notifyListeners();

    try {
      await _authService.deleteAccount();
      // 리스너가 Unauthenticated로 변경함
      return true;
    } catch (e) {
      _state = AuthError('계정 삭제 실패: $e');
      notifyListeners();
      return false;
    }
  }

  /// 약관 동의 후 데이터 저장 (신규 회원 -> 정식 회원 전환)
  /// 기존 syncUserDataToFirestore 역할을 대체
  Future<bool> convertToRegisteredUser() async {
    final currentState = _state;
    if (currentState is! Authenticated) return false;

    if (!currentState.isNewUser) return true; // 이미 등록된 회원

    try {
      final prefs = await SharedPreferences.getInstance();
      final termsAgreed = prefs.getBool('terms_agreed') ?? false;
      if (!termsAgreed) return false;

      // DB 저장
      final termsAgreedAt = prefs.getString('terms_agreed_at');
      final newUserModel = currentState.userModel.copyWith(
        termsVersion: TermsVersion.termsVersion,
        privacyVersion: TermsVersion.privacyVersion,
        createdAt: termsAgreedAt != null ? DateTime.parse(termsAgreedAt) : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _authService.saveUserToFirestore(newUserModel);

      // 상태 업데이트 (isNewUser: false)
      _state = Authenticated(currentState.user, newUserModel, isNewUser: false);
      notifyListeners();
      return true;
    } catch (e) {
      // 에러 처리 (상태를 Error로 바꾸지 않고 false 반환하여 UI에서 스낵바 처리 유도)
      return false;
    }
  }
  
  // 기존 코드와의 호환성을 위해 유지 (Main에서 호출하는 경우 제거 예정이지만 View에서 쓸 수 있음)
  Future<bool> syncUserDataToFirestore() => convertToRegisteredUser();
  
  // 수동 로그인 플래그 - 리팩토링 후에는 상태로 관리되므로 더미 메서드 (컴파일 에러 방지)
  void resetManualLoginFlag() {}
}
