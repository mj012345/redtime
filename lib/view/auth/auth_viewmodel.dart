import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      debugPrint(
        '🔔 [AuthViewModel] authStateChanges 이벤트: ${user?.uid ?? "null"}',
      );

      if (user != null) {
        // 현재 사용자와 동일하면 중복 호출 방지
        if (_currentUser?.uid == user.uid && _userModel != null) {
          debugPrint('ℹ️ [AuthViewModel] 동일 사용자 - 중복 호출 방지');
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
              debugPrint('authStateChanges 에러: $e');
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

  /// Firestore에서 사용자 데이터 로드 (재시도 로직 포함)
  Future<void> _loadUserDataWithRetry(String uid, {int maxRetries = 3}) async {
    // 이미 로딩 중이면 중복 호출 방지
    if (_isLoadingUserData) {
      debugPrint('⚠️ [AuthViewModel] 이미 사용자 데이터 로딩 중 - 중복 호출 방지');
      return;
    }

    _isLoadingUserData = true;
    _userLoadState = UserLoadState.userLoading;
    notifyListeners();

    try {
      for (int i = 0; i < maxRetries; i++) {
        try {
          debugPrint(
            '🔄 [AuthViewModel] Firestore 사용자 데이터 로드 시도 ${i + 1}/$maxRetries',
          );

          final userModel = await _authService
              .getUserFromFirestore(uid)
              .timeout(
                Duration(seconds: 10 + i * 5), // 점진적 타임아웃 증가 (10s, 15s, 20s)
                onTimeout: () {
                  debugPrint(
                    '⏰ [AuthViewModel] Firestore 조회 타임아웃 (시도 ${i + 1}/$maxRetries)',
                  );
                  throw TimeoutException('Firestore 조회 타임아웃');
                },
              );

          if (userModel != null) {
            _userModel = userModel;
            _isNewUser = false;
            _userLoadState = UserLoadState.userLoaded;
            debugPrint('✅ [AuthViewModel] Firestore 사용자 데이터 로드 성공');
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
            debugPrint('✨ [AuthViewModel] 신규 사용자로 확인');
            notifyListeners();
            return;
          }
        } on TimeoutException catch (e) {
          debugPrint(
            '⏰ [AuthViewModel] Firestore 조회 타임아웃 (시도 ${i + 1}/$maxRetries): $e',
          );
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
            debugPrint('⚠️ [AuthViewModel] Firestore 조회 최종 실패 - 미확인 상태로 처리');
            notifyListeners();
          } else {
            // 재시도 전 대기 (exponential backoff: 1s, 3s, 5s)
            await Future.delayed(Duration(seconds: 1 + i * 2));
          }
        } catch (e) {
          debugPrint(
            '❌ [AuthViewModel] Firestore 조회 에러 (시도 ${i + 1}/$maxRetries): $e',
          );

          // FirebaseException의 경우 권한 문제인지 확인
          if (e is FirebaseException && e.code == 'permission-denied') {
            debugPrint(
              '🚫 [AuthViewModel] Firestore 권한 거부 - Security Rules 확인 필요',
            );
          }

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
            debugPrint('⚠️ [AuthViewModel] Firestore 조회 최종 실패 - 미확인 상태로 처리');
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
      debugPrint('🔐 [AuthViewModel] signInWithGoogle 시작');
      _isLoading = true;
      _errorMessage = null;
      _isNewUser = null;
      _isManualLogin = true; // 수동 로그인 표시
      notifyListeners();
      debugPrint('🔐 [AuthViewModel] signInWithGoogle - 플래그 설정 완료');

      debugPrint('🔐 [AuthViewModel] signInWithGoogle - AuthService 호출 시작');
      final result = await _authService.signInWithGoogle();
      debugPrint(
        '🔐 [AuthViewModel] signInWithGoogle - AuthService 호출 완료: ${result != null}',
      );

      if (result != null) {
        debugPrint('🔐 [AuthViewModel] signInWithGoogle - 로그인 성공');
        debugPrint('  - userModel.uid: ${result.userModel.uid}');
        debugPrint(
          '  - isNewUser: ${result.isNewUser ?? "null (Firestore 조회 실패)"}',
        );
        _userModel = result.userModel;
        _currentUser = _authService.currentUser;
        _isNewUser = result.isNewUser; // null 가능 (Firestore 조회 실패 시)
        _isLoading = false;
        notifyListeners();
        debugPrint('🔐 [AuthViewModel] signInWithGoogle - 완료 (true)');
        // Firebase Auth 로그인 성공 시 true 반환 (Firestore 조회 실패와 무관)
        return true;
      } else {
        debugPrint(
          '🔐 [AuthViewModel] signInWithGoogle - 로그인 실패 (result == null)',
        );
        _isLoading = false;
        _isNewUser = null;
        notifyListeners();
        debugPrint('🔐 [AuthViewModel] signInWithGoogle - 완료 (false)');
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
      debugPrint('🚪 [AuthViewModel] 로그아웃 시작');
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
        debugPrint('⚠️ [AuthViewModel] 로그아웃 후 currentUser 남아있음 - 재시도');
        await _authService.signOut();
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ [AuthViewModel] 로그아웃 완료');
    } catch (e) {
      debugPrint('❌ [AuthViewModel] 로그아웃 실패: $e');
      _errorMessage = '로그아웃 실패: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 계정 삭제
  Future<bool> deleteAccount() async {
    try {
      debugPrint('🗑️ [AuthViewModel] 계정 삭제 시작');
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

      debugPrint('✅ [AuthViewModel] 계정 삭제 완료');
      return true;
    } catch (e) {
      debugPrint('❌ [AuthViewModel] 계정 삭제 에러: $e');
      _errorMessage = '계정 삭제 실패: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 사용자 데이터가 DB에 저장되어 있는지 확인하고, 없으면 저장 시도
  /// 약관 동의 완료 후 또는 달력 화면 진입 시 호출
  Future<bool> syncUserDataToFirestore() async {
    if (_currentUser == null || _userModel == null) {
      debugPrint(
        '⚠️ [AuthViewModel] syncUserDataToFirestore: currentUser 또는 userModel이 null',
      );
      return false;
    }

    // 이미 DB에 저장되어 있는지 확인
    if (_isNewUser == false) {
      debugPrint('✅ [AuthViewModel] syncUserDataToFirestore: 이미 기존 회원으로 확인됨');
      return true;
    }

    // isNewUser가 null인 경우 (미확인 상태) 또는 true인 경우 (신규 회원) DB 확인 필요
    debugPrint(
      '🔄 [AuthViewModel] syncUserDataToFirestore: DB 저장 상태 확인 및 동기화 시작',
    );

    try {
      // Firestore에서 사용자 정보 확인 (타임아웃 짧게)
      final existingUserModel = await _authService
          .getUserFromFirestore(_currentUser!.uid)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                '⏰ [AuthViewModel] syncUserDataToFirestore: DB 조회 타임아웃',
              );
              return null;
            },
          );

      if (existingUserModel != null) {
        // DB에 이미 있음 (기존 회원)
        _userModel = existingUserModel;
        _isNewUser = false;
        _userLoadState = UserLoadState.userLoaded;
        debugPrint(
          '✅ [AuthViewModel] syncUserDataToFirestore: DB에 이미 저장되어 있음 (기존 회원)',
        );
        notifyListeners();
        return true;
      }

      // DB에 없음 - 약관 동의 정보가 있으면 저장 시도
      debugPrint(
        '⚠️ [AuthViewModel] syncUserDataToFirestore: DB에 사용자 정보 없음 - 저장 시도',
      );

      // SharedPreferences에서 약관 동의 정보 확인
      final prefs = await SharedPreferences.getInstance();
      final termsAgreed = prefs.getBool('terms_agreed') ?? false;

      if (!termsAgreed) {
        debugPrint(
          '⚠️ [AuthViewModel] syncUserDataToFirestore: 약관 동의 정보 없음 - 저장하지 않음',
        );
        return false;
      }

      // 약관 동의 정보가 있으면 Firestore에 저장
      final termsAgreedAt = prefs.getString('terms_agreed_at');
      final newUserModel = UserModel(
        uid: _userModel!.uid,
        email: _userModel!.email,
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
      debugPrint('✅ [AuthViewModel] syncUserDataToFirestore: DB에 사용자 정보 저장 완료');
      notifyListeners();
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        '❌ [AuthViewModel] syncUserDataToFirestore: 동기화 실패: ${e.code} - ${e.message}',
      );
      // 권한 문제인지 확인
      if (e.code == 'permission-denied') {
        debugPrint(
          '🚫 [AuthViewModel] syncUserDataToFirestore: Firestore 권한 거부 - Security Rules 확인 필요',
        );
      }
      return false;
    } catch (e) {
      debugPrint('❌ [AuthViewModel] syncUserDataToFirestore: 동기화 실패: $e');
      return false;
    }
  }
}
