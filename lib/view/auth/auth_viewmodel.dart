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
        print('🔄 [AuthViewModel] 로그인 상태 변경 감지 - 사용자 ID: ${user.uid}');
        _currentUser = user;
        _validateAndLoadUser(user)
            .then((_) {
              notifyListeners();
            })
            .catchError((e) {
              print('❌ [AuthViewModel] 사용자 검증 중 에러: $e');
              notifyListeners();
            });
      } else {
        print('🔄 [AuthViewModel] 로그인 상태 변경 감지 - 로그아웃됨');
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
      print('🔍 [AuthViewModel] 앱 시작 시 사용자 유효성 검증 시작: ${user.uid}');
      await _validateAndLoadUser(user);
      notifyListeners();
    } else {
      print('🔍 [AuthViewModel] 앱 시작 시 로그인된 사용자 없음');
    }
  }

  /// 사용자 유효성 검증 및 로드
  Future<void> _validateAndLoadUser(User user) async {
    print(
      '🔍 [AuthViewModel] 사용자 유효성 검증 시작 - ID: ${user.uid}, 이메일: ${user.email}',
    );
    try {
      // 사용자 정보 갱신 (Firebase에서 삭제되었는지 확인)
      print('🔄 [AuthViewModel] 사용자 정보 갱신 중...');
      await user.reload();
      print('✅ [AuthViewModel] 사용자 정보 갱신 완료');

      // 갱신된 사용자 정보 가져오기
      final updatedUser = _authService.currentUser;
      if (updatedUser == null) {
        print('⚠️ [AuthViewModel] 사용자가 삭제되었거나 유효하지 않습니다. 로그아웃 처리합니다.');
        await signOut();
        return;
      }

      // 토큰 유효성 확인
      try {
        await updatedUser.getIdToken(true); // 강제 갱신
        print('✅ [AuthViewModel] 사용자 토큰 유효성 확인 완료: ${updatedUser.uid}');
      } catch (e) {
        print('❌ [AuthViewModel] 토큰 유효성 확인 실패: $e');
        print('⚠️ [AuthViewModel] 사용자가 유효하지 않습니다. 로그아웃 처리합니다.');
        await signOut();
        return;
      }

      // Firestore에서 사용자 정보 확인 (권한 오류 발생 시 로그인 실패)
      try {
        final userModel = await _authService.getUserFromFirestore(
          updatedUser.uid,
        );
        if (userModel == null) {
          print('⚠️ [AuthViewModel] Firestore에 사용자 정보가 없습니다. 새로 생성합니다.');
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
        print('❌ [AuthViewModel] Firestore 권한 오류 발생: $e');
        print(
          '⚠️ [AuthViewModel] Firestore 보안 규칙이 올바르게 설정되지 않았습니다. 로그아웃 처리합니다.',
        );
        // Firestore 권한 오류 발생 시 로그인 실패
        await signOut();
        return;
      }

      _currentUser = updatedUser;
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ [AuthViewModel] 사용자 유효성 검증 실패: $e');
      print('❌ [AuthViewModel] Stack trace: $stackTrace');
      // 에러 발생 시 로그아웃 처리
      print('⚠️ [AuthViewModel] 에러로 인해 로그아웃 처리합니다.');
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
      print('구글 로그인 상세 오류: $e');
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
