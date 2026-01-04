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

      // 1. 구글 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 로그인 취소
        return null;
      }

      // 2. 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Firebase 인증 자격 증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase에 로그인
      final UserCredential userCredential = await _auth!.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user == null) {
        return null;
      }

      // 5. 추가 프로필 정보 가져오기 (Google People API 사용 불가 시 기본값)
      // 참고: Google People API는 별도 설정이 필요하므로, 기본 프로필 정보만 사용
      final String? birthDate = null; // People API 연동 시 추가
      final String? gender = null; // People API 연동 시 추가
      final String? phoneNumber = null; // People API 연동 시 추가

      // 6. Firestore에 사용자 정보 저장/업데이트
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoURL: user.photoURL,
        birthDate: birthDate,
        gender: gender,
        phoneNumber: phoneNumber,
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
