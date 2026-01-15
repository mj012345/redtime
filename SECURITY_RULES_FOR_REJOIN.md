# Security Rules - 재가입 지원

`isDeleted: true` 상태에서도 재가입이 가능하도록 Security Rules를 업데이트해야 합니다.

## 업데이트된 Security Rules

Firebase Console > Firestore Database > Rules 탭에서 다음 규칙으로 업데이트하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function: 사용자 문서가 삭제되지 않았는지 확인
    function isNotDeleted(userId) {
      return get(/databases/$(database)/documents/users/$(userId)).data.isDeleted != true;
    }

    // Helper function: 재가입 업데이트인지 확인 (isDeleted를 false로 변경)
    function isRejoinUpdate(userId) {
      let existingDoc = get(/databases/$(database)/documents/users/$(userId));
      return existingDoc.data.isDeleted == true &&
             request.resource.data.isDeleted == false;
    }

    // 사용자 데이터
    match /users/{userId} {
      // 읽기: 로그인되어 있고, 본인 데이터이며, 삭제되지 않은 경우만
      // 단, 재가입을 위해 isDeleted: true인 문서도 읽을 수 있도록 허용
      allow read: if request.auth != null &&
                    request.auth.uid == userId;

      // 쓰기: 로그인되어 있고, 본인 데이터이며, 삭제되지 않은 경우
      // 또는 재가입 업데이트인 경우 (isDeleted: true → false)
      allow write: if request.auth != null &&
                     request.auth.uid == userId &&
                     (isNotDeleted(userId) || isRejoinUpdate(userId));

      // 업데이트: 일반 업데이트 또는 재가입 업데이트 허용
      allow update: if request.auth != null &&
                      request.auth.uid == userId &&
                      (isNotDeleted(userId) || isRejoinUpdate(userId));

      // 삭제 표시 업데이트는 허용 (Soft Delete용)
      // isDeleted를 true로 설정하는 것도 허용
      allow update: if request.auth != null &&
                      request.auth.uid == userId &&
                      request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['isDeleted', 'deletedAt', 'updatedAt']);

      // 하위 컬렉션
      match /{allPaths=**} {
        // 읽기/쓰기: 로그인되어 있고, 본인 데이터이며, 삭제되지 않은 경우만
        allow read, write: if request.auth != null &&
                             request.auth.uid == userId &&
                             isNotDeleted(userId);
      }
    }

    // deleted_users 컬렉션 (서버에서만 접근 가능)
    match /deleted_users/{userId} {
      allow read, write: if false;

      match /{allPaths=**} {
        allow read, write: if false;
      }
    }
  }
}
```

## 주요 변경사항

1. **읽기 권한 확대**: `isDeleted: true`인 문서도 본인이 읽을 수 있도록 허용 (재가입 시 필요)
2. **재가입 업데이트 허용**: `isRejoinUpdate` 함수로 `isDeleted: true → false` 변경 허용
3. **일반 업데이트**: `isNotDeleted` 체크로 일반 사용자 업데이트 허용
4. **하위 컬렉션**: 기존과 동일하게 `isNotDeleted` 체크 유지

## 동작 방식

1. **일반 사용자**: `isDeleted != true`인 경우 정상적으로 읽기/쓰기 가능
2. **탈퇴 사용자**: `isDeleted: true`인 경우 읽기는 가능하지만 쓰기는 제한됨
3. **재가입**: `isDeleted: true → false` 변경 시 업데이트 허용
4. **하위 컬렉션**: `isDeleted: true`인 경우 하위 컬렉션 접근 불가 (기존 데이터 보호)

## 테스트

1. 계정 삭제 후 재가입 시도
2. `isDeleted: false`로 변경되는지 확인
3. 재가입 후 정상적으로 데이터 접근 가능한지 확인
