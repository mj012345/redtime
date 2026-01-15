# Firestore Security Rules - 최종 버전

Firebase Console > Firestore Database > Rules 탭에서 다음 규칙으로 업데이트하세요.

## 최종 Security Rules (개선된 버전)

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
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isDeleted', 'deletedAt', 'updatedAt']) // 탈퇴 처리 중일 때
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

## 주요 개선사항

1. **신규 유저 생성 명시**: `!exists(...) && request.resource.data.isDeleted == false` 조건 추가
2. **재가입 안전성**: `exists()` 체크 추가하여 문서 존재 여부 확인
3. **하위 컬렉션**: `{allPaths=**}` 패턴으로 모든 하위 경로 포함

## 적용 방법

1. Firebase Console 열기
2. Firestore Database > Rules 탭 이동
3. 위 규칙을 복사하여 붙여넣기
4. "게시" 버튼 클릭

## 테스트 시나리오

1. ✅ 신규 유저 생성: `users/{userId}` 문서 생성
2. ✅ 일반 사용자: 증상/주기 저장
3. ✅ 탈퇴 처리: `isDeleted: true` 설정
4. ✅ 재가입: `isDeleted: false`로 변경
5. ✅ 탈퇴 후 데이터 접근: 하위 컬렉션 접근 차단

