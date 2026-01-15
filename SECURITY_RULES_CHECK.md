# Security Rules 적용 확인 및 문제 해결

## 현재 문제

로그에서 `permission-denied` 에러가 발생하고 있습니다:
- 경로: `users/CKDhF6yUuEUjaUtBg8eDpkRJawx1/periodCycles`
- `writeCount`가 0이지만 `permission-denied` 발생

## 원인 분석

1. **빈 batch commit 문제**: `periodCycles`가 비어있어도 `batch.commit()`을 호출하여 Security Rules 검증이 실행됨
2. **Security Rules 미적용 가능성**: Firebase Console에서 규칙이 아직 업데이트되지 않았을 수 있음

## 해결 방법

### 1. 코드 수정 (완료)

`period_repository.dart`에서 빈 batch는 commit하지 않도록 수정했습니다.

### 2. Security Rules 확인 및 적용

Firebase Console에서 다음 규칙이 적용되었는지 확인하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // [함수] 삭제된 유저인지 확인
    function isNotDeleted(userId) {
      // 문서가 없으면 신규 유저이므로 true 반환
      return !exists(/databases/$(database)/documents/users/$(userId)) || 
             get(/databases/$(database)/documents/users/$(userId)).data.isDeleted != true;
    }

    match /users/{userId} {
      // 1. 읽기: 본인 확인만 되면 허용 (그래야 탈퇴 여부를 체크함)
      allow read: if request.auth != null && request.auth.uid == userId;

      // 2. 쓰기(생성/수정): 
      allow write: if request.auth != null && request.auth.uid == userId && (
        isNotDeleted(userId) || // 삭제 안 됐거나
        (!exists(/databases/$(database)/documents/users/$(userId)) && request.resource.data.isDeleted == false) || // 신규 생성이거나
        (exists(/databases/$(database)/documents/users/$(userId)) && 
         get(/databases/$(database)/documents/users/$(userId)).data.isDeleted == true && 
         request.resource.data.isDeleted == false) || // 재가입 중이거나
        (exists(/databases/$(database)/documents/users/$(userId)) &&
         request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isDeleted', 'deletedAt', 'updatedAt'])) // 탈퇴 처리 중일 때
      );

      // 3. 하위 데이터 (생리 주기, 증상 등): 삭제된 상태면 본인이라도 접근 불가
      match /{allPaths=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId && isNotDeleted(userId);
      }
    }

    // 4. 탈퇴 데이터: 앱에서는 절대 접근 불가 (서버 전용)
    match /deleted_users/{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 확인 사항

1. ✅ Firebase Console > Firestore Database > Rules 탭에서 위 규칙이 적용되었는지 확인
2. ✅ "게시" 버튼을 눌러 규칙이 배포되었는지 확인
3. ✅ 규칙 배포 후 몇 분 대기 (규칙 적용에 시간이 걸릴 수 있음)
4. ✅ 앱 재시작 후 다시 테스트

## 테스트

1. 앱 재시작
2. 증상 저장 시도
3. 주기 저장 시도
4. 로그에서 `permission-denied` 에러가 사라졌는지 확인

