import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/services/firebase_service.dart';

/// 인증 서비스: 구글 로그인 및 사용자 정보 관리
class AuthService {
  FirebaseAuth? get _auth {
    if (!FirebaseService.checkInitialized()) return null;
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    if (!FirebaseService.checkInitialized()) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      // 참고: 생년월일, 성별, 전화번호는 Google People API가 필요하며
      // 별도의 API 활성화 및 OAuth 동의 화면 설정이 필요합니다.
      // 현재는 기본 프로필 정보(이메일, 이름, 프로필 사진)만 수집합니다.
      // 'https://www.googleapis.com/auth/user.birthday.read',
      // 'https://www.googleapis.com/auth/user.gender.read',
      // 'https://www.googleapis.com/auth/user.phonenumbers.read',
    ],
    // serverClientId를 명시하지 않으면 google-services.json에서 자동으로 찾습니다
    // ApiException: 10 발생 시 Firebase Console에서 SHA-1 인증서 지문 등록 확인 필요
  );

  /// 현재 로그인된 사용자
  User? get currentUser => _auth?.currentUser;

  /// 로그인 상태 스트림
  Stream<User?> get authStateChanges {
    if (_auth == null) {
      return Stream.value(null);
    }
    return _auth!.authStateChanges();
  }

  /// 구글 로그인 및 Firestore에 사용자 정보 저장
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Firebase 초기화 확인
      final isInitialized = FirebaseService.checkInitialized();

      if (!isInitialized || _auth == null) {
        throw Exception('Firebase가 초기화되지 않았습니다. 앱을 재시작해주세요.');
      }

      // 1. Firebase 세션 정리
      try {
        if (_auth!.currentUser != null) {
          await _auth!.signOut();
        }
      } catch (e) {
        // 이미 로그아웃된 경우 무시
      }

      // 2. Google Sign In 세션 정리 (항상 계정 선택 화면이 나오도록)
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // 이미 로그아웃된 경우 무시
      }

      // 3. 구글 로그인 (계정 선택 화면 표시)
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } on PlatformException catch (e) {
        debugPrint('Google Sign In 에러: ${e.code} - ${e.message}');

        if (e.code == 'sign_in_failed') {
          if (e.message?.contains('ApiException: 10') == true) {
            throw Exception('Google 로그인 설정 오류 (ApiException: 10)');
          }
          throw Exception('Google 로그인에 실패했습니다.');
        }
        rethrow;
      } catch (e) {
        debugPrint('Google Sign In 예외: $e');
        rethrow;
      }

      if (googleUser == null) {
        // 사용자가 로그인 취소
        return null;
      }

      // 3. 인증 정보 가져오기
      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Google 인증 토큰이 없습니다.');
      }

      // 4. Firebase에 로그인
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        return null;
      }

      // 6. Firestore에서 기존 사용자 정보 확인
      final existingUserModel = await getUserFromFirestore(user.uid);
      final isNewUser = existingUserModel == null;

      // 7. 기존 회원이면 기존 정보로 로그인, 신규 회원이면 새로 생성
      final userModel = existingUserModel != null
          ? UserModel(
              // 기존 회원: 기존 정보 유지, 프로필 정보만 업데이트
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName ?? existingUserModel.displayName,
              photoURL: user.photoURL ?? existingUserModel.photoURL,
              birthDate: existingUserModel.birthDate,
              gender: existingUserModel.gender,
              phoneNumber: existingUserModel.phoneNumber,
              createdAt: existingUserModel.createdAt, // 기존 생성일 유지
              updatedAt: DateTime.now(),
            )
          : UserModel(
              // 신규 회원: 새로 생성
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName,
              photoURL: user.photoURL,
              birthDate: null,
              gender: null,
              phoneNumber: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // 8. Firestore에 저장 (신규 회원은 반드시 성공해야 함)
      try {
        await saveUserToFirestore(userModel);
      } catch (e) {
        // 신규 회원인데 저장 실패하면 Firebase Auth에서 로그아웃하고 예외 던지기
        if (isNewUser) {
          debugPrint('신규 회원 Firestore 저장 실패: $e');
          try {
            await _auth!.signOut();
          } catch (_) {
            // 로그아웃 실패는 무시
          }
          throw Exception('회원가입에 실패했습니다. 다시 시도해주세요.');
        } else {
          // 기존 회원은 업데이트 실패해도 로그인 허용 (프로필 정보만 업데이트 안 됨)
          debugPrint('기존 회원 Firestore 업데이트 실패: $e');
        }
      }

      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  /// Firestore에 사용자 정보 저장 (없으면 생성, 있으면 업데이트)
  Future<void> saveUserToFirestore(UserModel userModel) async {
    if (_firestore == null) {
      throw Exception('Firestore가 초기화되지 않았습니다.');
    }

    try {
      final userRef = _firestore!.collection('users').doc(userModel.uid);

      final docSnapshot = await userRef.get();
      if (docSnapshot.exists) {
        // 기존 사용자: updatedAt만 업데이트
        await userRef.update({
          'displayName': userModel.displayName,
          'photoURL': userModel.photoURL,
          'updatedAt': userModel.updatedAt.toIso8601String(),
        });
      } else {
        // 신규 사용자: 전체 정보 저장
        await userRef.set(userModel.toMap());
      }
    } catch (e) {
      debugPrint('Firestore 저장 실패: $e');
      rethrow;
    }
  }

  /// Firestore에서 사용자 정보 가져오기
  Future<UserModel?> getUserFromFirestore(String uid) async {
    try {
      if (_firestore == null) {
        return null;
      }

      final docSnapshot = await _firestore!.collection('users').doc(uid).get();
      if (docSnapshot.exists) {
        return UserModel.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// 로그아웃 - 모든 세션 완전히 정리
  Future<void> signOut() async {
    final futures = <Future<void>>[];

    // Google Sign In 연결 완전히 해제 (disconnect)
    try {
      final currentAccount = await _googleSignIn.signInSilently();
      if (currentAccount != null) {
        futures.add(_googleSignIn.disconnect());
      }
    } catch (_) {
      // 계정이 없거나 오류 발생 시 무시하고 계속 진행
    }

    // Google Sign In 로그아웃
    try {
      futures.add(_googleSignIn.signOut());
    } catch (_) {}

    // Firebase 로그아웃
    if (_auth != null) {
      try {
        futures.add(_auth!.signOut());
      } catch (_) {}
    }

    // 모든 로그아웃 작업 완료 대기
    await Future.wait(futures, eagerError: false);
  }
}
