# 회원가입 로직 정리

## 전체 회원가입 플로우

```
로그인 화면 (LoginView)
  ↓
Google 로그인 버튼 클릭
  ↓
Google 계정 선택
  ↓
Firebase Auth에 로그인 (signInWithCredential)
  ↓
Firestore에서 기존 사용자 확인
  ├─ 기존 회원 (Firestore에 데이터 있음) → 달력 화면 (/calendar)
  └─ 신규 회원 (Firestore에 데이터 없음) → 약관 동의 화면 (/terms)
       ↓
       약관 동의 화면 (TermsAgreementView)
       ↓
       '동의하고 시작하기' 버튼 클릭
       ↓
       Firebase Firestore에 사용자 정보 저장
       ↓
       회원가입 완료 화면 (/signup-complete)
       ↓
       '홈화면으로 이동' 버튼 클릭
       ↓
       달력 화면 (/calendar)
```

## 1. 로그인 화면 (LoginView)

### 위치

- `lib/view/auth/login_view.dart`

### 주요 동작

1. **Google 로그인 버튼 클릭**
2. `AuthViewModel.signInWithGoogle()` 호출
3. **성공 시 화면 분기**:
   - **신규 회원** (`isNewUser == true`) → 약관 동의 화면 (`/terms`)
   - **기존 회원** (`isNewUser == false`) → 달력 화면 (`/calendar`)
4. **실패 시**: 에러 메시지 표시 (SnackBar)

## 2. Google 로그인 처리 (AuthService.signInWithGoogle)

### 위치

- `lib/services/auth_service.dart` (52-144줄)

### 주요 동작

1. **Firebase 초기화 확인**
2. **Firebase 세션 정리** (기존 로그인 있으면 로그아웃)
3. **Google Sign-In 세션 정리** (항상 계정 선택 화면이 나오도록)
4. **Google 로그인** (`_googleSignIn.signIn()`)
   - 계정 선택 화면 표시
   - 사용자 취소 시 `null` 반환
5. **Google 인증 정보 가져오기** (`googleUser.authentication`)
   - `accessToken`, `idToken` 확인
6. **⚠️ Firebase Auth에 로그인** (`signInWithCredential`)
   - **여기서 Firebase Authentication에 사용자가 생성됨**
   - `User` 객체 얻음
7. **Firestore에서 기존 사용자 정보 확인** (`getUserFromFirestore(user.uid)`)
   - `existingUserModel`이 있으면 → 기존 회원 (`isNewUser = false`)
   - `existingUserModel`이 없으면 → 신규 회원 (`isNewUser = true`)
8. **UserModel 생성**:
   - 기존 회원: `existingUserModel` 그대로 사용
   - 신규 회원: 새 `UserModel` 생성 (이메일만, `uid`는 Firebase Auth User의 `uid` 사용)
9. **❌ Firestore에는 저장하지 않음** (약관 동의 후 저장)
10. `SignInResult(userModel, isNewUser)` 반환

## 3. 약관 동의 화면 (TermsAgreementView)

### 위치

- `lib/view/auth/terms_agreement_view.dart`

### 접근 조건

- **신규 회원만 접근** (`isNewUser == true`)

### 주요 동작

#### 3-1. 뒤로가기

- `_handleBack()` 메서드:
  1. `AuthService.signOut()` 호출 (Firebase Auth + Google Sign-In 로그아웃)
  2. 로그인 화면 (`/login`)으로 이동

#### 3-2. 약관 동의 후 (`_handleAgreement`)

1. **SharedPreferences에 약관 동의 정보 저장**:

   - `terms_agreed: true`
   - `terms_agreed_at: DateTime.now()`

2. **Firestore에 사용자 정보 저장**:

   - `AuthService.currentUser` 확인 (Firebase Auth에 로그인된 상태)
   - `UserModel` 생성 (약관 버전 정보 포함):
     - `uid`: Firebase Auth User의 `uid`
     - `email`: Firebase Auth User의 `email`
     - `termsVersion`: `TermsVersion.termsVersion`
     - `privacyVersion`: `TermsVersion.privacyVersion`
   - `AuthService.saveUserToFirestore(newUserModel)` 호출

3. **에러 처리**:

   - `FirebaseException`: Firestore 에러 (네트워크, 권한 등)
   - `PlatformException`: 플랫폼 에러
   - 기타 예외: 일반 에러
   - 에러 발생 시: SnackBar로 에러 메시지 표시, 화면 이동하지 않음

4. **성공 시**: 회원가입 완료 화면 (`/signup-complete`)으로 이동

## 4. 회원가입 완료 화면 (SignupCompleteView)

### 위치

- `lib/view/auth/signup_complete_view.dart`

### 주요 동작

1. **회원가입 완료 메시지 표시**:

   - 체크 아이콘 (원형 배경)
   - "회원가입이 완료되었어요" 텍스트
   - 설명 텍스트

2. **'홈화면으로 이동' 버튼**:
   - 클릭 시 달력 화면 (`/calendar`)으로 이동

## 5. 데이터 저장 시점

### Firebase Authentication

- **시점**: Google 로그인 시 (`signInWithCredential` 호출)
- **위치**: `AuthService.signInWithGoogle()` (113줄)
- **상태**: ⚠️ 약관 동의 전에 생성됨 (문제점)

### Firestore (users/{uid})

- **시점**: 약관 동의 후 (`_handleAgreement` 메서드)
- **위치**: `TermsAgreementView._handleAgreement()` (248줄)
- **상태**: ✅ 올바름 (약관 버전 포함하여 저장)

### SharedPreferences

- **시점**: 약관 동의 후 (`_handleAgreement` 메서드)
- **저장 데이터**:
  - `terms_agreed: true`
  - `terms_agreed_at: DateTime.now().toIso8601String()`

## 현재 문제점

### ⚠️ Firebase Auth에 사용자가 생성되는 시점

- **현재**: Google 로그인 시점 (`signInWithCredential` 호출)
- **문제**: 약관 동의 화면까지 도달할 때 이미 Firebase Authentication에 사용자가 생성됨
- **요구사항**: 약관 동의 후 ('동의하고 시작하기' 버튼 클릭 시)에만 Firebase Authentication에 사용자를 생성해야 함

## 파일 구조

```
lib/
├── services/
│   └── auth_service.dart          # 인증 서비스 (Google 로그인, Firestore 저장)
├── view/
│   └── auth/
│       ├── auth_viewmodel.dart    # 인증 상태 관리 (ViewModel)
│       ├── login_view.dart        # 로그인 화면
│       ├── terms_agreement_view.dart  # 약관 동의 화면
│       └── signup_complete_view.dart  # 회원가입 완료 화면
├── models/
│   └── user_model.dart            # 사용자 정보 모델
├── constants/
│   └── terms_version.dart         # 약관 버전 상수
└── main.dart                      # AuthWrapper, 라우팅

```

## 라우팅 경로

- `/login`: 로그인 화면 (LoginView)
- `/terms`: 약관 동의 화면 (TermsAgreementView)
- `/signup-complete`: 회원가입 완료 화면 (SignupCompleteView)
- `/calendar`: 달력 화면 (FigmaCalendarPage) - 메인 화면
