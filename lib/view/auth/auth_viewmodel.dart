import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  bool? _isNewUser; // 신규/기존 회원 구분 (null: 미확인, true: 신규, false: 기존)

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool? get isNewUser => _isNewUser;
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
          // 신규 사용자: 약관 동의 전이므로 Firestore에 저장하지 않음
          // 로컬 UserModel만 생성 (약관 동의 후 저장됨)
          _userModel = UserModel(
            uid: updatedUser.uid,
            email: updatedUser.email ?? '',
            displayName: null,
            photoURL: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      } catch (_) {
        // Firestore 조회 실패 시 이메일만 사용 (Firestore 저장하지 않음)
        _userModel = UserModel(
          uid: updatedUser.uid,
          email: updatedUser.email ?? '',
          displayName: null,
          photoURL: null,
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
      _isNewUser = null;
      notifyListeners();

      final result = await _authService.signInWithGoogle();
      if (result != null) {
        _userModel = result.userModel;
        _currentUser = _authService.currentUser;
        _isNewUser = result.isNewUser;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _isNewUser = null;
        notifyListeners();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      // Firebase Auth 에러 타입 활용
      String userMessage;
      String debugMessage;

      switch (e.code) {
        case 'network-request-failed':
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
          debugMessage = '❌ Firebase Auth 네트워크 오류 [${e.code}]: ${e.message}';
          break;
        case 'user-disabled':
          userMessage = '사용할 수 없는 계정입니다.';
          debugMessage = '❌ Firebase Auth 계정 비활성화 [${e.code}]: ${e.message}';
          break;
        case 'invalid-credential':
          userMessage = '인증 정보가 올바르지 않습니다.';
          debugMessage = '❌ Firebase Auth 잘못된 인증 정보 [${e.code}]: ${e.message}';
          break;
        case 'operation-not-allowed':
          userMessage = 'Google 로그인이 허용되지 않았습니다.';
          debugMessage = '❌ Firebase Auth 운영 미허용 [${e.code}]: ${e.message}';
          break;
        case 'user-not-found':
          userMessage = '사용자 계정을 찾을 수 없습니다.';
          debugMessage = '❌ Firebase Auth 사용자 없음 [${e.code}]: ${e.message}';
          break;
        case 'wrong-password':
          userMessage = '인증 정보가 올바르지 않습니다.';
          debugMessage = '❌ Firebase Auth 잘못된 비밀번호 [${e.code}]: ${e.message}';
          break;
        default:
          userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
          debugMessage = '❌ Firebase Auth 알 수 없는 에러 [${e.code}]: ${e.message}';
      }

      // 개발자용 디버그 콘솔 로그
      debugPrint('=== Firebase Auth 에러 ===');
      debugPrint(debugMessage);
      debugPrint('에러 코드: ${e.code}');
      debugPrint('에러 메시지: ${e.message}');
      debugPrint('에러 스택: ${StackTrace.current}');
      debugPrint('===================');

      _errorMessage = userMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } on PlatformException catch (e) {
      // Platform 에러 (Google Sign-In 등)
      String userMessage;
      String debugMessage;

      if (e.code == 'sign_in_failed') {
        if (e.message?.contains('ApiException: 10') == true) {
          userMessage =
              'Google 로그인 설정 오류가 발생했습니다.\nFirebase Console에서 SHA-1 지문을 확인해주세요.';
          debugMessage =
              '❌ Google Sign-In 설정 오류 [${e.code}]: ApiException: 10 - ${e.message}';
        } else if (e.message?.toLowerCase().contains('network') == true ||
            e.message?.toLowerCase().contains('connection') == true) {
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
          debugMessage = '❌ Google Sign-In 네트워크 오류 [${e.code}]: ${e.message}';
        } else {
          userMessage = 'Google 로그인에 실패했습니다.';
          debugMessage = '❌ Google Sign-In 실패 [${e.code}]: ${e.message}';
        }
      } else {
        userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
        debugMessage = '❌ Platform 알 수 없는 에러 [${e.code}]: ${e.message}';
      }

      // 개발자용 디버그 콘솔 로그
      debugPrint('=== Platform 에러 ===');
      debugPrint(debugMessage);
      debugPrint('에러 코드: ${e.code}');
      debugPrint('에러 메시지: ${e.message}');
      debugPrint('에러 세부사항: ${e.details}');
      debugPrint('에러 스택: ${StackTrace.current}');
      debugPrint('===================');

      _errorMessage = userMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // 기타 예외 (일반 Exception 등)
      final errorString = e.toString().toLowerCase();
      String? userMessage;
      String debugMessage;

      if (errorString.contains('canceled') ||
          errorString.contains('cancelled')) {
        // 사용자 취소는 에러 메시지 표시하지 않음
        userMessage = null;
        debugMessage = '✅ 사용자 로그인 취소: $e';
      } else if (errorString.contains('회원가입') ||
          errorString.contains('signup') ||
          errorString.contains('sign up')) {
        // 회원가입 에러
        if (errorString.contains('network') ||
            errorString.contains('connection')) {
          userMessage = '네트워크 오류로 회원가입에 실패했습니다. 인터넷 연결을 확인해주세요.';
          debugMessage = '❌ 회원가입 네트워크 오류 [${e.runtimeType}]: $e';
        } else {
          userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
          debugMessage = '❌ 회원가입 실패 [${e.runtimeType}]: $e';
        }
      } else if (errorString.contains('network') ||
          errorString.contains('connection')) {
        userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
        debugMessage = '❌ 네트워크 오류 [${e.runtimeType}]: $e';
      } else {
        userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
        debugMessage = '❌ 알 수 없는 에러 [${e.runtimeType}]: $e';
      }

      // 개발자용 디버그 콘솔 로그
      debugPrint('=== 기타 에러 ===');
      debugPrint(debugMessage);
      debugPrint('에러 타입: ${e.runtimeType}');
      debugPrint('에러 메시지: $e');
      debugPrint('에러 스택: ${StackTrace.current}');
      debugPrint('===================');

      _errorMessage = userMessage;
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

  /// 계정 삭제
  Future<bool> deleteAccount() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _authService.deleteAccount();
      _currentUser = null;
      _userModel = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('계정 삭제 에러: $e');
      _errorMessage = '계정 삭제 실패: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
