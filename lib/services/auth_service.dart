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

      // 1. Firebase 세션만 정리
      // Google Sign In은 계정 선택 화면을 제공하므로 signOut() 불필요
      // signOut() 후 바로 signIn() 호출 시 ApiException: 10 발생 가능
      try {
        if (_auth!.currentUser != null) {
          await _auth!.signOut();
        }
      } catch (e) {
        // 이미 로그아웃된 경우 무시
      }

      // 2. 구글 로그인 (계정 선택 화면 표시)
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } on PlatformException catch (e) {
        // 상세 에러 로깅 (디버깅용)
        debugPrint('=== Google Sign In 에러 상세 ===');
        debugPrint('에러 코드: ${e.code}');
        debugPrint('에러 메시지: ${e.message}');
        debugPrint('상세 정보: $e');
        debugPrint('디테일: ${e.details}');
        debugPrint('==============================');

        // ApiException: 10은 Firebase 설정 문제 (SHA-1 인증서 지문 미등록 등)
        if (e.code == 'sign_in_failed' &&
            e.message?.contains('ApiException: 10') == true) {
          throw Exception(
            'Google 로그인 설정 오류 (ApiException: 10)\n\n'
            '해결 방법:\n'
            '1. Firebase Console > 프로젝트 설정 > SHA-1 지문 등록\n'
            '   SHA-1: EE:B6:E8:29:DE:0A:B9:9C:50:36:51:9E:7F:44:F4:51:4C:61:7C:ED\n'
            '2. 등록 후 google-services.json 새로 다운로드\n'
            '3. 시뮬레이터 사용 시: 실제 Android 기기에서 테스트 권장',
          );
        } else if (e.code == 'sign_in_failed') {
          throw Exception(
            'Google 로그인에 실패했습니다.\n\n'
            '인터넷 연결을 확인하거나 잠시 후 다시 시도해주세요.',
          );
        } else {
          throw Exception('Google 로그인 오류가 발생했습니다.\n\n다시 시도해주세요.');
        }
      } catch (e) {
        // PlatformException이 아닌 다른 예외
        debugPrint('Google Sign In 예외 (PlatformException 아님): $e');
        rethrow;
      }

      if (googleUser == null) {
        // 사용자가 로그인 취소
        return null;
      }

      // 3. 인증 정보 가져오기
      GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication;
      } catch (e) {
        throw Exception('Google 인증 정보를 가져오는데 실패했습니다: $e');
      }

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Google 인증 토큰이 없습니다.');
      }

      // 4. Firebase 인증 자격 증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Firebase에 로그인
      UserCredential userCredential;
      try {
        userCredential = await _auth!.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        throw Exception('Firebase 인증 실패: ${e.code} - ${e.message}');
      } catch (e) {
        throw Exception('Firebase 로그인 실패: $e');
      }
      final User? user = userCredential.user;

      if (user == null) {
        return null;
      }

      // 6. Firestore에서 기존 사용자 정보 확인
      final existingUserModel = await getUserFromFirestore(user.uid);

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

      await saveUserToFirestore(userModel);

      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  /// Firestore에 사용자 정보 저장 (없으면 생성, 있으면 업데이트)
  Future<void> saveUserToFirestore(UserModel userModel) async {
    if (_firestore == null) {
      return;
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

  /// 로그아웃
  Future<void> signOut() async {
    final futures = <Future<void>>[_googleSignIn.signOut()];
    if (_auth != null) {
      futures.add(_auth!.signOut());
    }
    await Future.wait(futures);
  }
}
