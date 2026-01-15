# Firestore Security Rules - 단순화된 버전 (디버깅용)

현재 `permission-denied` 에러가 계속 발생하고 있습니다. 더 단순하고 명확한 규칙으로 테스트해보세요.

## 단순화된 Security Rules (테스트용)

먼저 이 규칙으로 테스트하여 기본 접근이 작동하는지 확인하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 사용자 데이터 및 모든 하위 컬렉션
    match /users/{userId}/{document=**} {
      // 로그인되어 있고 본인 데이터면 모든 접근 허용
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // deleted_users는 서버 전용
    match /deleted_users/{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 이 규칙이 작동하면

이 규칙으로 저장이 성공하면, 다음 단계로 `isDeleted` 체크를 추가하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // [함수] 삭제된 유저인지 확인 (안전한 버전)
    function isNotDeleted(userId) {
      let userDoc = get(/databases/$(database)/documents/users/$(userId));
      // 문서가 없으면 신규 유저 (true 반환)
      // 문서가 있으면 isDeleted 필드 확인
      return !exists(/databases/$(database)/documents/users/$(userId)) || 
             (userDoc != null && userDoc.data.isDeleted != true);
    }

    // 사용자 데이터
    match /users/{userId} {
      // 읽기: 본인 확인만
      allow read: if request.auth != null && request.auth.uid == userId;

      // 쓰기: 본인이고 삭제되지 않은 경우
      allow write: if request.auth != null && 
                     request.auth.uid == userId && 
                     isNotDeleted(userId);
      
      // Soft Delete 업데이트 허용
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['isDeleted', 'deletedAt', 'updatedAt']);
      
      // 재가입 허용
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      exists(/databases/$(database)/documents/users/$(userId)) &&
                      get(/databases/$(database)/documents/users/$(userId)).data.isDeleted == true &&
                      request.resource.data.isDeleted == false;

      // 하위 컬렉션: periodCycles
      match /periodCycles/{document=**} {
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId && 
                             isNotDeleted(userId);
      }
      
      // 하위 컬렉션: symptoms
      match /symptoms/{document=**} {
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId && 
                             isNotDeleted(userId);
      }
    }

    // deleted_users는 서버 전용
    match /deleted_users/{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 적용 방법

1. Firebase Console 열기
2. Firestore Database > Rules 탭 이동
3. **먼저 단순화된 규칙**을 붙여넣고 "게시"
4. 앱에서 저장 테스트
5. 성공하면 **두 번째 규칙**으로 교체

## 확인 사항

1. ✅ Firebase Console에서 규칙이 "게시됨" 상태인지 확인
2. ✅ 규칙 배포 후 1-2분 대기
3. ✅ 앱 재시작
4. ✅ 로그에서 현재 사용자 ID 확인 (`🔍 [PeriodRepository] 저장 시도` 로그 확인)

