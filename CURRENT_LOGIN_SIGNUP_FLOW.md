# 현재 로그인/회원가입 로직 정리

## 전체 플로우

```
앱 시작 (AuthWrapper)
  ↓
로그인 상태 확인
  ├─ 로그인됨 → 달력 화면 (FigmaCalendarPage)
  └─ 로그인 안됨 → 로그인 화면 (LoginView)
```

## 1. 로그인 화면 (LoginView)

### 위치
- `lib/view/auth/login_view.dart`

### 주요 동작

1. **Google 로그인 버튼 클릭**
   - 단순히 약관 동의 화면으로 이동 (`Navigator.pushReplacementNamed('/terms')`)
   - **Google 로그인을 수행하지 않음** (약관 동의 후에 수행)

2. **화면 이동**
   - 약관 동의 화면 (`/terms`)으로 이동

### 특징
- Google 로그인 로직이 없음 (단순 화면 전환만)
- `AuthViewModel`을 사용하지 않음
- `SocialLoginButton`의 `isLoading`은 항상 `false`

## 2. 약관 동의 화면 (TermsAgreementView)

### 위치
- `lib/view/auth/terms_agreement_view.dart`

### 접근 조건
- 로그인 화면에서 Google 로그인 버튼 클릭 시 접근
- **약관 동의 전이므로 아직 Firebase Auth 사용자가 생성되지 않음**

### 주요 동작

#### 2-1. 뒤로가기 (`_handleBack`)
1. `Navigator.pushReplacementNamed('/login')` 호출
2. 로그인 화면으로 이동

#### 2-2. 약관 동의 후 (`_handleAgreement`)

1. **약관 동의 정보 저장 (SharedPreferences)**
   - `terms_agreed: true`
   - `terms_agreed_at: DateTime.now().toIso8601String()`
   - 실패해도 계속 진행 (치명적이지 않음)

2. **Google 로그인 진행** (`AuthService.signInWithGoogle()`)
   - **여기서 처음 Google 로그인이 수행됨**
   - Google 계정 선택 화면 표시
   - Firebase Auth에 로그인 (`signInWithCredential`)
   - **이 시점에 Firebase Authentication 사용자가 생성됨**

3. **에러 처리**:
   - `FirebaseException`: Firebase Auth 에러 (네트워크, 권한 등)
   - `PlatformException`: Google Sign-In 에러 (ApiException: 10 등)
   - 기타 예외: 일반 에러
   - 사용자 취소: 에러 메시지 표시하지 않음

4. **신규/기존 회원 확인** (`SignInResult.isNewUser`)

   **신규 회원** (`isNewUser == true`):
   - Firestore에 사용자 정보 저장 (`saveUserToFirestore`)
     - `uid`: Firebase Auth User의 `uid`
     - `email`: Firebase Auth User의 `email`
     - `termsVersion`: `TermsVersion.termsVersion`
     - `privacyVersion`: `TermsVersion.privacyVersion`
     - `createdAt`, `updatedAt`: 현재 시간
   - Firestore 저장 에러 처리:
     - `FirebaseException`: Firestore 네트워크 오류, 권한 거부 등
     - `PlatformException`: 플랫폼 에러
     - 기타 예외: 일반 에러
   - 성공 시: 회원가입 완료 화면 (`/signup-complete`)으로 이동

   **기존 회원** (`isNewUser == false`):
   - 바로 달력 화면 (`/calendar`)으로 이동
   - Firestore 저장 생략

## 3. AuthService.signInWithGoogle()

### 위치
- `lib/services/auth_service.dart` (52-144줄)

### 주요 동작

1. **Firebase 초기화 확인**
   - `FirebaseService.checkInitialized()` 확인
   - 실패 시 예외 발생

2. **Firebase 세션 정리**
   - 기존 로그인 있으면 `_auth.signOut()` 호출
   - 이미 로그아웃된 경우 무시

3. **Google Sign-In 세션 정리**
   - `_googleSignIn.signOut()` 호출
   - 항상 계정 선택 화면이 나오도록 보장
   - 이미 로그아웃된 경우 무시

4. **Google 로그인** (`_googleSignIn.signIn()`)
   - 계정 선택 화면 표시
   - 사용자 취소 시 `null` 반환
   - `PlatformException` 처리:
     - `sign_in_failed`: 에러 메시지 확인
     - `ApiException: 10`: Google 로그인 설정 오류

5. **Google 인증 정보 가져오기** (`googleUser.authentication`)
   - `accessToken`, `idToken` 확인
   - 없으면 예외 발생

6. **Firebase Auth에 로그인** (`signInWithCredential`)
   - `GoogleAuthProvider.credential` 생성
   - `_auth.signInWithCredential(credential)` 호출
   - **이 시점에 Firebase Authentication 사용자가 생성됨**
   - `User` 객체 얻음

7. **Firestore에서 기존 사용자 정보 확인** (`getUserFromFirestore(user.uid)`)
   - `existingUserModel`이 있으면 → 기존 회원 (`isNewUser = false`)
   - `existingUserModel`이 없으면 → 신규 회원 (`isNewUser = true`)

8. **UserModel 생성**
   - 기존 회원: `existingUserModel` 그대로 사용
   - 신규 회원: 새 `UserModel` 생성 (이메일만, `uid`는 Firebase Auth User의 `uid` 사용)

9. **Firestore에는 저장하지 않음**
   - 약관 동의 후 TermsAgreementView에서 저장됨

10. `SignInResult(userModel, isNewUser)` 반환

## 4. AuthService.saveUserToFirestore()

### 위치
- `lib/services/auth_service.dart` (147-160줄)

### 주요 동작

1. Firestore 초기화 확인
2. `users/{uid}` 문서에 `userModel.toMap()` 저장
3. 약관 버전 정보 포함하여 저장
4. **신규 회원만 호출됨** (TermsAgreementView에서)

## 5. 회원가입 완료 화면 (SignupCompleteView)

### 위치
- `lib/view/auth/signup_complete_view.dart`

### 접근 조건
- 신규 회원이 약관 동의 후 Firestore 저장 성공 시 접근

### 주요 동작

1. "회원가입이 완료되었어요" 메시지 표시
2. "홈화면으로 이동" 버튼 클릭
3. 달력 화면 (`/calendar`)으로 이동

## 6. 앱 시작 시 (AuthWrapper)

### 위치
- `lib/main.dart` (154-284줄)

### 주요 동작

1. **Firebase 초기화 확인**
   - `FirebaseService.checkInitialized()` 확인
   - 실패 시 로그인 화면 표시

2. **로그인 상태 확인**
   - `FirebaseAuth.instance.currentUser` 확인
   - 있으면:
     - `user.reload()` 호출 (최대 5초 타임아웃)
     - `getIdToken(true)` 호출하여 토큰 유효성 확인
     - 유효하면 → 달력 화면 (`FigmaCalendarPage`)
     - 무효하면 → 로그아웃 후 로그인 화면 (`LoginView`)
   - 없으면 → 로그인 화면 (`LoginView`)

## 7. 라우팅 경로

- `/login`: 로그인 화면 (LoginView)
- `/terms`: 약관 동의 화면 (TermsAgreementView)
- `/signup-complete`: 회원가입 완료 화면 (SignupCompleteView)
- `/calendar`: 달력 화면 (FigmaCalendarPage) - 메인 화면
- `/terms-page`: 이용약관 페이지 (TermsPageView)
- `/privacy-page`: 개인정보처리방침 페이지 (TermsPageView)

## 주요 변경사항

### ✅ 약관 동의 전 Firebase Auth 사용자 생성 방지

**이전 플로우** (문제):
1. Google 로그인 버튼 클릭 → Google 로그인 → Firebase Auth 사용자 생성
2. 약관 동의 화면 이동
3. 약관 동의 후 Firestore 저장

**현재 플로우** (해결):
1. Google 로그인 버튼 클릭 → 약관 동의 화면 이동 (로그인 없음)
2. 약관 동의 체크
3. '동의하고 시작하기' 버튼 클릭 → Google 로그인 → Firebase Auth 사용자 생성
4. 신규 회원: Firestore 저장 → 회원가입 완료 화면

### ✅ 약관 동의 필수화

- 모든 사용자는 약관 동의 화면을 거쳐야 함
- 약관 동의 없이는 Google 로그인 자체가 수행되지 않음
- 약관 동의 후에만 Firebase Auth 사용자가 생성됨

## 데이터 흐름

```
1. 로그인 화면
   └─ 사용자 액션: Google 로그인 버튼 클릭
   
2. 약관 동의 화면
   ├─ 사용자 액션: 약관 동의 체크
   ├─ 사용자 액션: '동의하고 시작하기' 버튼 클릭
   ├─ Google 로그인 수행 (AuthService.signInWithGoogle)
   ├─ Firebase Auth 사용자 생성 ⚠️
   ├─ Firestore에서 기존 사용자 확인
   │
   ├─ 신규 회원 (isNewUser == true)
   │  ├─ Firestore에 사용자 정보 저장 (약관 버전 포함)
   │  └─ 회원가입 완료 화면으로 이동
   │
   └─ 기존 회원 (isNewUser == false)
      └─ 달력 화면으로 이동

3. 회원가입 완료 화면 (신규 회원만)
   └─ 사용자 액션: '홈화면으로 이동' 버튼 클릭
      └─ 달력 화면으로 이동
```

## 에러 처리

### Google 로그인 에러
- `FirebaseException`: Firebase Auth 에러 (네트워크, 권한 등)
- `PlatformException`: Google Sign-In 에러 (ApiException: 10 등)
- 사용자 취소: 에러 메시지 표시하지 않음

### Firestore 저장 에러 (신규 회원만)
- `FirebaseException`: Firestore 네트워크 오류, 권한 거부 등
- `PlatformException`: 플랫폼 에러
- 기타 예외: 일반 에러

### 모든 에러
- 사용자에게는 친화적인 메시지 표시 (SnackBar)
- 개발자에게는 상세한 디버그 로그 출력 (debugPrint)

## 상태 관리

- `TermsAgreementView`는 자체 상태 관리 (`StatefulWidget`)
  - `_isLoading`: 로딩 상태
  - `_termsAgreed`: 이용약관 동의 상태
  - `_privacyAgreed`: 개인정보처리방침 동의 상태
  - `_allAgreed`: 전체 동의 상태 (자동 계산)

- `AuthViewModel`은 현재 LoginView에서 사용하지 않음
  - `signInWithGoogle()` 메서드는 유지되어 있지만 현재 사용되지 않음
  - 향후 필요할 수 있어 유지

