# Firestore Security Rules - 상용 배포 버전

상용 환경에서는 삭제된 사용자가 데이터에 접근하지 못하도록 `isDeleted` 체크가 **필수**입니다.

## 중요: 성능 최적화

이전에 `isNotDeleted` 함수가 하위 컬렉션 접근 시마다 `get()`을 호출하여 성능 문제가 발생했지만, **Firestore Rules는 동일한 요청 내에서 `get()` 결과를 캐싱**합니다. 즉:
- 한 번의 배치 작업에서 여러 문서에 접근해도 `get()`은 한 번만 실행됨
- 성능 영향이 최소화됨

## 상용 배포용 Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // [함수] 삭제된 유저인지 확인 (최적화된 버전)
    function isNotDeleted(userId) {
      // 문서가 없으면 신규 유저 (true 반환)
      // 문서가 있으면 isDeleted 필드 확인
      let userDoc = get(/databases/$(database)/documents/users/$(userId));
      return userDoc == null || userDoc.data.isDeleted != true;
    }

    // 사용자 문서
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
        // isNotDeleted 체크는 필수이지만, Firestore가 동일 요청 내에서 캐싱하므로 성능 영향 최소화
        allow read, write: if request.auth != null && 
                             request.auth.uid == userId && 
                             isNotDeleted(userId);
      }
      
      // 하위 컬렉션: symptoms (명시적으로 매칭)
      match /symptoms/{monthDoc} {
        // isNotDeleted 체크는 필수이지만, Firestore가 동일 요청 내에서 캐싱하므로 성능 영향 최소화
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

## 보안 검증 시나리오

다음 시나리오를 테스트하세요:

1. ✅ **정상 사용자**: 데이터 읽기/쓰기 정상 작동
2. ✅ **삭제된 사용자**: `isDeleted: true` 설정 후 데이터 접근 차단 확인
3. ✅ **재가입**: `isDeleted: false`로 변경 후 데이터 접근 복구 확인
4. ✅ **Soft Delete**: 계정 삭제 시 `isDeleted: true` 설정 가능 확인

## 적용 방법

1. **테스트 환경에서 먼저 검증**
   - Firebase Console > Firestore Database > Rules 탭
   - 위 규칙을 붙여넣고 "게시"
   - 규칙 배포 후 1-2분 대기
   - 앱 재시작 후 모든 기능 테스트

2. **성능 모니터링**
   - Firestore Console > Usage 탭에서 읽기/쓰기 횟수 확인
   - 읽기 횟수가 예상보다 많으면 규칙 최적화 검토

3. **상용 배포**
   - 테스트 환경에서 검증 완료 후 상용 환경에 적용

## 성능 최적화 설명

Firestore Security Rules는 **동일한 요청 내에서 `get()` 결과를 캐싱**합니다:

```javascript
// 예: 배치 작업에서 10개 문서 저장 시
// isNotDeleted(userId) 함수가 10번 호출되지만
// get(/databases/$(database)/documents/users/$(userId))는 1번만 실행됨
```

따라서 성능 영향이 최소화됩니다.

## 주의사항

- ⚠️ 규칙 배포 후 즉시 적용되므로, 테스트 환경에서 먼저 검증하세요
- ⚠️ 성능 문제가 발생하면 Firestore Console에서 읽기 횟수를 확인하세요
- ⚠️ 필요시 Cloud Functions에서 추가 검증 로직을 구현할 수 있습니다
