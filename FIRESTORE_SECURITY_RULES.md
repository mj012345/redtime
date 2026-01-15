# Firestore Security Rules - 완전한 버전

Firebase Console > Firestore Database > Rules 탭에서 다음 규칙으로 업데이트하세요.

## 전체 Security Rules

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
      
      // 하위 컬렉션: periodCycles
      match /periodCycles/{document=**} {
        // 읽기/쓰기: 로그인되어 있고, 본인 데이터이며, 삭제되지 않은 경우만
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId && 
                             isNotDeleted(userId);
      }
      
      // 하위 컬렉션: symptoms
      match /symptoms/{document=**} {
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

## 주요 포인트

1. **하위 컬렉션 명시**: `periodCycles`와 `symptoms`를 명시적으로 매칭하여 권한 부여
2. **isNotDeleted 체크**: 하위 컬렉션에도 `isNotDeleted` 함수 적용
3. **재가입 지원**: `isDeleted: true`인 문서도 읽기 가능 (재가입용)
4. **Soft Delete**: `isDeleted` 필드 업데이트 허용

## 적용 방법

1. Firebase Console 열기
2. Firestore Database > Rules 탭 이동
3. 위 규칙을 복사하여 붙여넣기
4. "게시" 버튼 클릭

## 테스트

규칙 적용 후:
1. 증상 저장 시도 → 성공해야 함
2. 주기 저장 시도 → 성공해야 함
3. 로그에서 `permission-denied` 에러가 사라져야 함

