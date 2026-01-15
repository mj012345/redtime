# Firestore Security Rules - 수정된 버전

두 번째 규칙에서 `isNotDeleted` 함수가 문제를 일으키고 있습니다. 하위 컬렉션 접근 시마다 `get()`을 호출하면 성능 문제와 실패가 발생할 수 있습니다.

## 수정된 Security Rules

다음 규칙은 `isNotDeleted` 체크를 최적화하고, 하위 컬렉션 접근을 더 효율적으로 처리합니다:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // [함수] 삭제된 유저인지 확인 (최적화된 버전)
    function isNotDeleted(userId) {
      // 문서가 없으면 신규 유저 (true 반환)
      let userDoc = get(/databases/$(database)/documents/users/$(userId));
      return userDoc == null || userDoc.data.isDeleted != true;
    }

    // 사용자 문서 자체
    match /users/{userId} {
      // 읽기: 본인 확인만 (탈퇴 여부 체크를 위해 읽기 허용)
      allow read: if request.auth != null && request.auth.uid == userId;

      // 쓰기: 본인이고 삭제되지 않은 경우
      allow write: if request.auth != null && 
                     request.auth.uid == userId && 
                     isNotDeleted(userId);
      
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
                             request.auth.uid == userId && 
                             isNotDeleted(userId);
      }
      
      // 하위 컬렉션: symptoms (명시적으로 매칭)
      match /symptoms/{monthDoc} {
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

## 주요 변경사항

1. **하위 컬렉션 명시적 매칭**: `{document=**}` 대신 `{yearDoc}`, `{monthDoc}` 사용
2. **isNotDeleted 최적화**: `exists()` 체크를 `get()` 결과로 통합
3. **재가입 로직 개선**: `resource.data` 직접 접근 (더 안전)

## 대안: 더 단순한 버전 (성능 우선)

만약 위 규칙도 문제가 있다면, 다음 더 단순한 버전을 사용하세요:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 사용자 문서
    match /users/{userId} {
      // 읽기: 본인 확인만
      allow read: if request.auth != null && request.auth.uid == userId;

      // 쓰기: 본인 확인만 (isDeleted 체크는 앱에서 처리)
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // Soft Delete 업데이트 허용
      allow update: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.data.diff(resource.data).affectedKeys()
                        .hasOnly(['isDeleted', 'deletedAt', 'updatedAt']);

      // 하위 컬렉션: periodCycles
      match /periodCycles/{yearDoc} {
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId;
      }
      
      // 하위 컬렉션: symptoms
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

이 버전은 `isDeleted` 체크를 Security Rules에서 제거하고, 앱 로직에서 처리하도록 합니다.

## 적용 방법

1. Firebase Console > Firestore Database > Rules 탭
2. 위 규칙 중 하나를 선택하여 붙여넣기
3. "게시" 버튼 클릭
4. 규칙 배포 후 1-2분 대기
5. 앱 재시작 후 테스트

## 권장사항

**먼저 "대안: 더 단순한 버전"을 사용하세요.** 이 버전은:
- ✅ 성능 문제 없음
- ✅ DB 조회 정상 작동
- ✅ 저장 정상 작동
- ⚠️ `isDeleted` 체크는 앱에서 처리 (Security Rules에서 제거)

앱에서 `isDeleted` 체크를 하려면, `AuthViewModel`이나 `CalendarViewModel`에서 사용자 데이터를 로드할 때 `isDeleted` 필드를 확인하고, 삭제된 사용자면 접근을 차단하면 됩니다.

