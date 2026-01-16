import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/services/auth_service.dart';
import 'package:red_time_app/constants/terms_version.dart';

/// 사용자 데이터 로딩 상태
enum UserLoadState {
  idle, // 초기 상태
  authReady, // Firebase Auth 로그인 완료, Firestore 조회 전
  userLoading, // Firestore 조회 중
  userLoaded, // Firestore 조회 성공
  userLoadFailed, // Firestore 조회 실패
}

/// 인증 상태 관리 뷰모델
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authStateSubscription;

  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  bool? _isNewUser; // 신규/기존 회원 구분 (null: 미확인, true: 신규, false: 기존)
  bool _isManualLogin = false; // 수동 로그인 여부 (로그인 버튼 클릭 시 true)
  UserLoadState _userLoadState = UserLoadState.idle; // 사용자 데이터 로딩 상태
  bool _isLoadingUserData = false; // 사용자 데이터 로딩 중 플래그 (중복 호출 방지)

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool? get isNewUser => _isNewUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isManualLogin => _isManualLogin; // 수동 로그인 여부 확인용
  UserLoadState get userLoadState => _userLoadState; // 사용자 데이터 로딩 상태

  /// 수동 로그인 플래그 리셋 (CalendarViewModel에서 호출)
  void resetManualLoginFlag() {
    _isManualLogin = false;
  }

  AuthViewModel() {
    // 로그인 상태 변화 감지 (먼저 설정)
    _authStateSubscription = _authService.authStateChanges.listen((User? user) {
      if (user != null) {
        // 현재 사용자와 동일하면 중복 호출 방지
        if (_currentUser?.uid == user.uid && _userModel != null) {
          return;
        }

        _currentUser = user;
        _validateAndLoadUser(user)
            .then((_) {
              // 수동 로그인이 아니면 자동 로그인으로 처리
              // _isManualLogin은 CalendarViewModel에서 확인 후 리셋됨
              notifyListeners();
            })
            .catchError((e) {
              notifyListeners();
            });
      } else {
        _currentUser = null;
        _userModel = null;
        _isNewUser = null;
        _isManualLogin = false; // 로그아웃 시 리셋
        _userLoadState = UserLoadState.idle;
        _isLoadingUserData = false; // 로딩 상태 초기화
        notifyListeners();
      }
    });

    // 앱 시작 시 현재 사용자 유효성 검증 (비동기로 실행)
    _validateCurrentUser();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    super.dispose();
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

      // Firestore에서 사용자 정보 확인 (재시도 로직 포함)
      _userLoadState = UserLoadState.authReady;
      notifyListeners();

      await _loadUserDataWithRetry(updatedUser.uid);

      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      // 토큰 관련 심각한 에러만 로그아웃
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('token') ||
          errorStr.contains('authentication') ||
          errorStr.contains('unauthorized')) {
        await signOut();
      }
    }
  }

  /// Firestore에서 사용자 데이터 로드 (재시도 로직 포함)
  Future<void> _loadUserDataWithRetry(String uid, {int maxRetries = 3}) async {
    // 이미 로딩 중이면 중복 호출 방지
    if (_isLoadingUserData) {
      return;
    }

    _isLoadingUserData = true;
    _userLoadState = UserLoadState.userLoading;
    notifyListeners();

    try {
      for (int i = 0; i < maxRetries; i++) {
        try {
          final userModel = await _authService
              .getUserFromFirestore(uid)
              .timeout(
                Duration(seconds: 10 + i * 5), // 점진적 타임아웃 증가 (10s, 15s, 20s)
                onTimeout: () {
                  throw TimeoutException('Firestore 조회 타임아웃');
                },
              );

          if (userModel != null) {
            _userModel = userModel;
            _isNewUser = false;
            _userLoadState = UserLoadState.userLoaded;
            notifyListeners();
            return;
          } else {
            // 신규 사용자: 약관 동의 전이므로 Firestore에 저장하지 않음
            // 로컬 UserModel만 생성 (약관 동의 후 저장됨)
            _userModel = UserModel(
              uid: uid,
              email: _currentUser?.email ?? '',
              displayName: null,
              photoURL: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _isNewUser = true;
            _userLoadState = UserLoadState.userLoaded;
            notifyListeners();
            return;
          }
        } on TimeoutException {
          if (i == maxRetries - 1) {
            // 마지막 시도 실패 시
            _userLoadState = UserLoadState.userLoadFailed;
            // Firestore 조회 실패 시 이메일만 사용 (Firestore 저장하지 않음)
            _userModel = UserModel(
              uid: uid,
              email: _currentUser?.email ?? '',
              displayName: null,
              photoURL: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _isNewUser = null; // 미확인 상태
            notifyListeners();
          } else {
            // 재시도 전 대기 (exponential backoff: 1s, 3s, 5s)
            await Future.delayed(Duration(seconds: 1 + i * 2));
          }
        } catch (e) {
          // FirebaseException의 경우 권한 문제인지 확인
          if (e is FirebaseException && e.code == 'permission-denied') {}

          if (i == maxRetries - 1) {
            // 마지막 시도 실패 시
            _userLoadState = UserLoadState.userLoadFailed;
            // Firestore 조회 실패 시 이메일만 사용 (Firestore 저장하지 않음)
            _userModel = UserModel(
              uid: uid,
              email: _currentUser?.email ?? '',
              displayName: null,
              photoURL: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            _isNewUser = null; // 미확인 상태
            notifyListeners();
          } else {
            // 재시도 전 대기 (exponential backoff: 1s, 3s, 5s)
            await Future.delayed(Duration(seconds: 1 + i * 2));
          }
        }
      }
    } finally {
      _isLoadingUserData = false; // 로딩 완료 표시
    }
  }

  /// 구글 로그인
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _isNewUser = null;
      _isManualLogin = true; // 수동 로그인 표시
      notifyListeners();
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        _userModel = result.userModel;
        _currentUser = _authService.currentUser;
        _isNewUser = result.isNewUser; // null 가능 (Firestore 조회 실패 시)
        _isLoading = false;
        notifyListeners();
        // Firebase Auth 로그인 성공 시 true 반환 (Firestore 조회 실패와 무관)
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

      switch (e.code) {
        case 'network-request-failed':
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
          break;
        case 'user-disabled':
          userMessage = '사용할 수 없는 계정입니다.';
          break;
        case 'invalid-credential':
          userMessage = '인증 정보가 올바르지 않습니다.';
          break;
        case 'operation-not-allowed':
          userMessage = 'Google 로그인이 허용되지 않았습니다.';
          break;
        case 'user-not-found':
          userMessage = '사용자 계정을 찾을 수 없습니다.';
          break;
        default:
          userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
      }
      _errorMessage = userMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } on PlatformException catch (e) {
      // Platform 에러 (Google Sign-In 등)
      String userMessage;

      if (e.code == 'sign_in_failed') {
        if (e.message?.contains('ApiException: 10') == true) {
          userMessage =
              'Google 로그인 설정 오류가 발생했습니다.\nFirebase Console에서 SHA-1 지문을 확인해주세요.';
        } else if (e.message?.toLowerCase().contains('network') == true ||
            e.message?.toLowerCase().contains('connection') == true) {
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
        } else {
          userMessage = 'Google 로그인에 실패했습니다.';
        }
      } else {
        userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
      }
      _errorMessage = userMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // 기타 예외 (일반 Exception 등)
      final errorString = e.toString().toLowerCase();
      String? userMessage;

      if (errorString.contains('canceled') ||
          errorString.contains('cancelled')) {
        // 사용자 취소는 에러 메시지 표시하지 않음
        userMessage = null;
      } else if (errorString.contains('network') ||
          errorString.contains('connection')) {
        userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
      } else {
        userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
      }
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

      // 로그아웃 완료 후 상태 초기화
      _currentUser = null;
      _userModel = null;
      _isNewUser = null;
      _isManualLogin = false;
      _errorMessage = null;

      // 추가 확인: authService의 currentUser도 확인
      final remainingUser = _authService.currentUser;
      if (remainingUser != null) {
        await _authService.signOut();
      }

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

      // 계정 삭제 성공 후 상태 초기화
      _currentUser = null;
      _userModel = null;
      _isNewUser = null;
      _isManualLogin = false;
      _userLoadState = UserLoadState.idle;
      _isLoadingUserData = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '계정 삭제 실패: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 사용자 데이터가 DB에 저장되어 있는지 확인하고, 없으면 저장 시도
  /// 약관 동의 완료 후 또는 달력 화면 진입 시 호출
  Future<bool> syncUserDataToFirestore() async {
    // null 체크 후 바로 로컬 변수에 저장 (비동기 작업 중 값 변경 방지)
    final currentUser = _currentUser;
    final userModel = _userModel;

    if (currentUser == null || userModel == null) {
      return false;
    }

    // 이미 DB에 저장되어 있는지 확인
    if (_isNewUser == false) {
      return true;
    }

    // isNewUser가 null인 경우 (미확인 상태) 또는 true인 경우 (신규 회원) DB 확인 필요
    try {
      // Firestore에서 사용자 정보 확인 (타임아웃 짧게)
      // 로컬 변수 사용 (null이 아님을 보장)
      final existingUserModel = await _authService
          .getUserFromFirestore(currentUser.uid)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              return null;
            },
          );

      if (existingUserModel != null) {
        // DB에 이미 있음 (기존 회원)
        _userModel = existingUserModel;
        _isNewUser = false;
        _userLoadState = UserLoadState.userLoaded;
        notifyListeners();
        return true;
      }

      // DB에 없음 - 약관 동의 정보가 있으면 저장 시도
      // SharedPreferences에서 약관 동의 정보 확인
      final prefs = await SharedPreferences.getInstance();
      final termsAgreed = prefs.getBool('terms_agreed') ?? false;

      if (!termsAgreed) {
        return false;
      }

      // 약관 동의 정보가 있으면 Firestore에 저장
      // 로컬 변수 사용 (null이 아님을 보장)
      final termsAgreedAt = prefs.getString('terms_agreed_at');
      final newUserModel = UserModel(
        uid: userModel.uid,
        email: userModel.email,
        displayName: null,
        photoURL: null,
        termsVersion: TermsVersion.termsVersion,
        privacyVersion: TermsVersion.privacyVersion,
        createdAt: termsAgreedAt != null
            ? DateTime.parse(termsAgreedAt)
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _authService.saveUserToFirestore(newUserModel);
      _userModel = newUserModel;
      _isNewUser = false;
      _userLoadState = UserLoadState.userLoaded;
      notifyListeners();
      return true;
    } on FirebaseException catch (e) {
      // 권한 문제인지 확인
      if (e.code == 'permission-denied') {}
      return false;
    } catch (e) {
      return false;
    }
  }
}
