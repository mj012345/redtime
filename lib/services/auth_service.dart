import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

      // 6. Firestore에서 기존 사용자 정보 확인
      final existingUserModel = await getUserFromFirestore(user.uid);
      final isNewUser = existingUserModel == null;

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
  Future<void> saveUserToFirestore(UserModel userModel) async {
    if (_firestore == null) {
      throw Exception('Firestore가 초기화되지 않았습니다.');
    }

    try {
      final userRef = _firestore!.collection('users').doc(userModel.uid);
      // 신규 사용자: 전체 정보 저장 (약관 버전 포함)
      await userRef.set(userModel.toMap());
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

  /// 계정 삭제 - 탈퇴 회원을 별도 컬렉션으로 이동
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
      // 사용자의 로그인 제공자 확인
      final providerId = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : '';

      if (providerId == 'google.com') {
        // Google 로그인 사용자
        GoogleSignInAccount? googleUser;
        try {
          // 현재 로그인된 Google 계정으로 재인증
          googleUser = await _googleSignIn.signInSilently();
          if (googleUser == null) {
            // 자동 재인증 실패 시 수동 로그인 요청
            googleUser = await _googleSignIn.signIn();
          }
        } catch (e) {
          debugPrint('Google 재인증 실패: $e');
          // 수동 로그인 시도
          googleUser = await _googleSignIn.signIn();
        }

        if (googleUser == null) {
          throw Exception('재인증이 취소되었습니다.');
        }

        // Google 인증 정보 가져오기
        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          throw Exception('Google 인증 토큰이 없습니다.');
        }

        // Firebase Auth에 재인증
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        // 기타 제공자 또는 알 수 없는 경우
        throw Exception('지원하지 않는 로그인 방식입니다.');
      }

      // 2. 사용자 정보 가져오기 (Firestore에 없어도 Firebase Auth 정보 사용)
      final userModel = await getUserFromFirestore(userId);

      // Firestore에 사용자 정보가 없어도 Firebase Auth 정보로 계정 삭제 진행
      final userData = userModel != null
          ? {
              'uid': userModel.uid,
              'email': userModel.email,
              'createdAt': userModel.createdAt.toIso8601String(),
              'updatedAt': userModel.updatedAt.toIso8601String(),
            }
          : {
              'uid': userId,
              'email': user.email ?? '',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            };

      // 3. 사용자의 모든 데이터 가져오기
      final userRef = _firestore!.collection('users').doc(userId);
      final periodCyclesRef = _firestore!.collection(
        'users/$userId/periodCycles',
      );
      final symptomsRef = _firestore!.collection('users/$userId/symptoms');

      final periodCyclesSnapshot = await periodCyclesRef.get();
      final symptomsSnapshot = await symptomsRef.get();

      // 4. Firebase Auth에서 사용자 삭제 (먼저 시도)
      // Auth 삭제가 성공해야만 데이터를 이동시킴
      await user.delete();

      // 5. Auth 삭제 성공 후 데이터 이동
      // 탈퇴 회원 정보 생성 (삭제일 추가)
      final deletedUserData = {
        ...userData,
        'deletedAt': DateTime.now().toIso8601String(),
        'originalUid': userId,
      };

      // 6. 탈퇴 회원 컬렉션에 데이터 저장
      final deletedUserRef = _firestore!
          .collection('deleted_users')
          .doc(userId);
      await deletedUserRef.set(deletedUserData);

      // 7. 생리 주기 데이터 이동
      if (periodCyclesSnapshot.docs.isNotEmpty) {
        final deletedPeriodCyclesRef = deletedUserRef.collection(
          'periodCycles',
        );
        final batch = _firestore!.batch();
        for (final doc in periodCyclesSnapshot.docs) {
          batch.set(deletedPeriodCyclesRef.doc(doc.id), doc.data());
        }
        await batch.commit();
      }

      // 8. 증상 데이터 이동
      if (symptomsSnapshot.docs.isNotEmpty) {
        final deletedSymptomsRef = deletedUserRef.collection('symptoms');
        final batch = _firestore!.batch();
        for (final doc in symptomsSnapshot.docs) {
          batch.set(deletedSymptomsRef.doc(doc.id), doc.data());
        }
        await batch.commit();
      }

      // 9. 원본 데이터 삭제
      final deleteBatch = _firestore!.batch();

      // 생리 주기 데이터 삭제
      for (final doc in periodCyclesSnapshot.docs) {
        deleteBatch.delete(doc.reference);
      }

      // 증상 데이터 삭제
      for (final doc in symptomsSnapshot.docs) {
        deleteBatch.delete(doc.reference);
      }

      // 사용자 정보 삭제
      deleteBatch.delete(userRef);

      await deleteBatch.commit();

      // 10. Google Sign In 연결 해제 (Google 로그인 사용자인 경우만)
      if (providerId == 'google.com') {
        try {
          await _googleSignIn.disconnect();
        } catch (_) {}

        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('계정 삭제 실패: $e');
      rethrow;
    }
  }
}
