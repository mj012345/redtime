import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/services/firebase_service.dart';
import 'package:red_time_app/services/sign_in_result.dart';

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
      // 참고: 이메일만 수집하며, 이름, 프로필 사진, 생년월일, 성별, 전화번호는 수집하지 않습니다.
      // 'profile' scope를 제거하여 이름과 프로필 사진 권한 요청을 방지합니다.
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

  /// 구글 로그인 및 신규/기존 회원 확인
  Future<SignInResult?> signInWithGoogle() async {
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
        if (e.code == 'sign_in_failed') {
          if (e.message?.contains('ApiException: 10') == true) {
            throw Exception('Google 로그인 설정 오류 (ApiException: 10)');
          }
          throw Exception('Google 로그인에 실패했습니다.');
        }
        rethrow;
      } catch (e) {
        rethrow;
      }

      if (googleUser == null) {
        // 사용자가 로그인 취소
        return null;
      }

      // 4. 인증 정보 가져오기
      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Google 인증 토큰이 없습니다.');
      }
      // 5. Firebase에 로그인
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth!.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) {
        return null;
      }

      // 6. Firestore에서 기존 사용자 정보 확인 (타임아웃 설정)
      UserModel? existingUserModel;
      bool? isNewUser; // null로 초기화 (미확인 상태)

      try {
        existingUserModel = await getUserFromFirestore(user.uid).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            return null; // 타임아웃 시 null 반환 (신규 회원으로 처리하지 않음)
          },
        );

        // 조회 성공 시에만 isNewUser 판정
        if (existingUserModel != null) {
          // isDeleted 체크: 삭제된 사용자는 신규 회원으로 처리하여 회원가입 진행
          if (existingUserModel.isDeleted == true) {
            // 신규 회원으로 처리하여 회원가입 진행
            isNewUser = true;
            existingUserModel = null; // 기존 모델 무시, 새로 생성
          } else {
            isNewUser = false; // 기존 회원 (삭제되지 않음)
          }
        } else {
          isNewUser = true; // 신규 회원 (문서가 없음)
        }
      } catch (e) {
        existingUserModel = null;
        isNewUser = null; // 에러 시 null (미확인 상태)
      }
      // 7. 기존 회원이면 기존 정보 사용, 신규 회원이면 새로 생성
      final userModel =
          existingUserModel ??
          UserModel(
            // 신규 회원: 이메일만 수집
            uid: user.uid,
            email: user.email ?? '',
            displayName: null,
            photoURL: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      // 8. 약관 동의 전에는 Firestore에 저장하지 않음 (약관 동의 후 저장)
      // 신규/기존 회원 모두 약관 동의 화면에서 약관 동의 후 저장
      return SignInResult(userModel: userModel, isNewUser: isNewUser);
    } catch (e) {
      rethrow;
    }
  }

  /// Firestore에 사용자 정보 저장 (신규 회원만 저장)
  /// 기존 문서가 있으면 덮어쓰지 않고 업데이트만 수행
  /// isDeleted: true인 경우 재가입 처리 (isDeleted: false로 변경)
  Future<void> saveUserToFirestore(UserModel userModel) async {
    if (_firestore == null) {
      throw Exception('Firestore가 초기화되지 않았습니다.');
    }

    try {
      final userRef = _firestore!.collection('users').doc(userModel.uid);

      // 기존 문서 존재 여부 확인 (데이터 덮어쓰기 방지)
      // isDeleted: true인 문서도 읽을 수 있도록 시도
      DocumentSnapshot? docSnapshot;
      try {
        docSnapshot = await userRef.get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          // Security Rules 때문에 읽을 수 없는 경우 (isDeleted: true일 수 있음)
          // 재가입을 위해 업데이트 시도
          docSnapshot = null; // null로 처리하여 재가입 로직 실행
        } else {
          rethrow;
        }
      }

      if (docSnapshot != null && docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>?;
        final isDeleted = data?['isDeleted'] == true;

        if (isDeleted) {
          // 재가입: isDeleted를 false로 변경하고 deletedAt 제거
          await userRef.update({
            'isDeleted': false,
            'deletedAt': FieldValue.delete(), // deletedAt 필드 제거
            'termsVersion': userModel.termsVersion,
            'privacyVersion': userModel.privacyVersion,
            'updatedAt': userModel.updatedAt.toIso8601String(),
          });
        } else {
          // 기존 회원: 약관 버전 정보만 업데이트 (기존 데이터 보존)
          await userRef.update({
            'termsVersion': userModel.termsVersion,
            'privacyVersion': userModel.privacyVersion,
            'updatedAt': userModel.updatedAt.toIso8601String(),
          });
        }
      } else {
        // 신규 사용자 또는 읽을 수 없는 경우: 전체 정보 저장 (약관 버전 포함)
        // 읽을 수 없는 경우(isDeleted: true일 수 있음)에도 재가입으로 처리
        try {
          // 먼저 업데이트 시도 (isDeleted: true인 경우)
          await userRef.update({
            'isDeleted': false,
            'deletedAt': FieldValue.delete(),
            ...userModel.toMap(),
          });
        } on FirebaseException catch (e) {
          if (e.code == 'not-found') {
            // 문서가 없는 경우 새로 생성
            await userRef.set(userModel.toMap());
          } else {
            rethrow;
          }
        }
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
      // GetOptions로 소스 명시 (캐시 우선, 실패 시 서버)
      final docSnapshot = await _firestore!
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data == null) {
          return null;
        }
        return UserModel.fromMap(data);
      }

      return null;
    } on FirebaseException catch (e) {
      // 권한 거부인 경우 명확히 로깅
      if (e.code == 'permission-denied') {
      } else if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {}
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// 로그아웃 - 모든 세션 완전히 정리
  Future<void> signOut() async {
    final futures = <Future<void>>[];

    // 1. Firebase 로그아웃 (먼저 실행)
    if (_auth != null) {
      try {
        futures.add(_auth!.signOut());
      } catch (e) {}
    }

    // 2. Google Sign In 로그아웃
    try {
      futures.add(_googleSignIn.signOut());
    } catch (e) {}

    // 3. Google Sign In 연결 완전히 해제 (disconnect)
    try {
      final currentAccount = await _googleSignIn.signInSilently();
      if (currentAccount != null) {
        futures.add(_googleSignIn.disconnect());
      }
    } catch (e) {
      // Google Sign In 연결 해제 중 오류 무시
    }

    // 모든 로그아웃 작업 완료 대기
    await Future.wait(futures, eagerError: false);

    // 4. 로그아웃 완료 확인 및 재시도
    int retryCount = 0;
    const maxRetries = 3;
    while (retryCount < maxRetries) {
      final currentUser = _auth?.currentUser;
      if (currentUser == null) {
        break;
      }
      try {
        await _auth!.signOut();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {}
      retryCount++;
    }

    // 5. SharedPreferences의 약관 동의 정보 삭제
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('terms_agreed');
      await prefs.remove('terms_agreed_at');
    } catch (e) {
      // SharedPreferences 삭제 실패 무시
    }

    // 6. 최종 확인
    final finalCheck = _auth?.currentUser;
    if (finalCheck == null) {
    } else {}
  }

  /// 계정 삭제 - Soft Delete 방식 (논리적 삭제)
  /// users/{userId} 문서에 isDeleted: true, deletedAt 추가
  Future<void> deleteAccount() async {
    if (_auth == null || _firestore == null) {
      throw Exception('Firebase가 초기화되지 않았습니다.');
    }

    final user = _auth!.currentUser;
    if (user == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    final userId = user.uid;

    try {
      // 1. 재인증 (계정 삭제는 민감한 작업이므로 재인증 필요)
      final providerId = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : '';

      if (providerId == 'google.com') {
        GoogleSignInAccount? googleUser;
        try {
          googleUser = await _googleSignIn.signInSilently();
          if (googleUser == null) {
            googleUser = await _googleSignIn.signIn();
          }
        } catch (e) {
          googleUser = await _googleSignIn.signIn();
        }

        if (googleUser == null) {
          throw Exception('재인증이 취소되었습니다.');
        }

        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('Google 인증 토큰이 없습니다.');
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        throw Exception('지원하지 않는 로그인 방식입니다.');
      }

      // 2. users/{userId} 문서에 isDeleted: true, deletedAt 추가 (Soft Delete)
      final userRef = _firestore!.collection('users').doc(userId);

      try {
        await userRef.update({
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(), // 서버 시간 사용
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        if (e.code == 'not-found') {
          // 문서가 없어도 Auth 삭제는 진행
        } else if (e.code == 'permission-denied') {
          throw Exception('계정 삭제 권한이 없습니다. Security Rules를 확인해주세요.');
        } else {
          throw Exception('계정 삭제 중 오류가 발생했습니다: ${e.message}');
        }
      }

      // 3. Firebase Auth에서 사용자 삭제
      await user.delete();
      // 4. Google Sign In 연결 해제 (Google 로그인 사용자인 경우만)
      if (providerId == 'google.com') {
        try {
          await _googleSignIn.disconnect();
        } catch (_) {}

        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }

      // 5. SharedPreferences의 약관 동의 정보 삭제
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('terms_agreed');
        await prefs.remove('terms_agreed_at');
      } catch (e) {
        // SharedPreferences 삭제 실패 무시
      }

      // 6. 최종 확인
      final finalCheck = _auth?.currentUser;
      if (finalCheck == null) {
      } else {}
    } catch (e) {
      rethrow;
    }
  }
}
