# Firestore Security Rules - 최종 버전 (성능 최적화)

두 번째 규칙에서 `isNotDeleted` 함수가 하위 컬렉션 접근 시마다 `get()`을 호출하여 성능 문제와 실패가 발생합니다.

## 문제 원인

하위 컬렉션(`periodCycles`, `symptoms`)에 접근할 때마다 `isNotDeleted(userId)` 함수가 `get(/databases/$(database)/documents/users/$(userId))`를 호출합니다. 이는:
- 매번 추가 읽기 작업 발생
- 성능 저하
- 규칙 평가 실패 가능성

## 해결 방법: 앱에서 isDeleted 체크

Security Rules에서는 기본 인증만 확인하고, `isDeleted` 체크는 앱 로직에서 처리합니다.

## 최종 Security Rules (권장)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 사용자 문서
    match /users/{userId} {
      // 읽기: 본인 확인만 (탈퇴 여부 체크를 위해 읽기 허용)
      allow read: if request.auth != null && request.auth.uid == userId;

      // 쓰기: 본인 확인만 (isDeleted 체크는 앱에서 처리)
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // Soft Delete 업데이트 허용 (isDeleted를 true로 설정)
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['isDeleted', 'deletedAt', 'updatedAt']);
      
      // 재가입 허용 (isDeleted를 false로 변경)
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      resource.data.isDeleted == true &&
                      request.resource.data.isDeleted == false;

      // 하위 컬렉션: periodCycles (명시적으로 매칭)
      match /periodCycles/{yearDoc} {
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId;
      }
      
      // 하위 컬렉션: symptoms (명시적으로 매칭)
      match /symptoms/{monthDoc} {
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId;
      }
    }

    // deleted_users는 서버 전용
    match /deleted_users/{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 앱에서 isDeleted 체크 추가

`CalendarViewModel`에서 데이터를 로드하기 전에 사용자가 삭제되지 않았는지 확인하도록 수정해야 합니다. 하지만 현재 `AuthViewModel`에서 이미 `userModel`을 로드하고 있으므로, `userModel.isDeleted`를 확인하면 됩니다.

## 적용 방법

1. Firebase Console > Firestore Database > Rules 탭
2. 위 규칙을 붙여넣고 "게시"
3. 규칙 배포 후 1-2분 대기
4. 앱 재시작 후 테스트

## 장점

- ✅ 성능 문제 없음 (하위 컬렉션 접근 시 추가 읽기 없음)
- ✅ DB 조회 정상 작동
- ✅ 저장 정상 작동
- ✅ 규칙 평가 실패 없음

## isDeleted 체크는 앱에서

`isDeleted` 체크는 앱 로직에서 처리합니다:
- `AuthViewModel`에서 `userModel.isDeleted` 확인
- 삭제된 사용자면 데이터 접근 차단
- Security Rules는 기본 인증만 확인

