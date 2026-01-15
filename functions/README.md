# Cloud Functions - 삭제된 계정 아카이브

이 Cloud Functions는 매일 밤 12시에 실행되어, 삭제 후 7일이 지난 계정을 `deleted_users` 컬렉션으로 이동합니다.

## 기능

- **자동 실행**: 매일 밤 12시 (한국 시간) 자동 실행
- **7일 유예 기간**: `isDeleted: true`이고 `deletedAt`이 7일 이전인 계정만 처리
- **데이터 이동**: `users/{userId}` → `deleted_users/{userId}`로 복사
- **원본 유지**: `users` 컬렉션의 데이터는 삭제하지 않고 유지

## 배포 방법

### 1. Firebase CLI 설치 및 로그인

```bash
npm install -g firebase-tools
firebase login
```

### 2. Firebase 프로젝트 초기화 (처음 한 번만)

```bash
firebase init functions
```

선택 사항:
- TypeScript 선택
- ESLint는 선택사항
- 기존 설정 덮어쓰기 안 함

### 3. 의존성 설치

```bash
cd functions
npm install
```

### 4. 빌드

```bash
npm run build
```

### 5. 배포

```bash
# 프로젝트 루트에서
firebase deploy --only functions:moveDeletedUsersToArchive
```

또는 모든 Functions 배포:

```bash
firebase deploy --only functions
```

## 로컬 테스트

```bash
cd functions
npm run serve
```

Firebase Emulator를 사용하여 로컬에서 테스트할 수 있습니다.

## 함수 확인

Firebase Console에서:
1. Functions > `moveDeletedUsersToArchive` 선택
2. "Trigger" 탭에서 스케줄 확인
3. "Logs" 탭에서 실행 로그 확인

## 수동 실행 (테스트용)

Firebase Console에서:
1. Functions > `moveDeletedUsersToArchive` 선택
2. "Test" 탭에서 "Test function" 클릭

## 주의사항

- 리전: `asia-northeast3` (서울) - 필요시 변경 가능
- 시간대: `Asia/Seoul` - 필요시 변경 가능
- Batch 제한: 한 번에 최대 500개 문서 처리
- 비용: Cloud Functions 실행 시간에 따라 과금

## Security Rules

`deleted_users` 컬렉션은 서버(Functions)에서만 접근 가능하도록 설정:

```javascript
match /deleted_users/{userId} {
  allow read, write: if false; // 클라이언트 접근 차단
}
```

