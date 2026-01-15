import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * 매일 밤 12시에 실행되는 스케줄러 함수
 * 삭제 후 7일이 지난 계정을 찾아 데이터를 deleted_users로 이동
 * (완전 삭제하지 않고 이동만 수행)
 */
export const moveDeletedUsersToArchive = functions
  .region('asia-northeast3') // 서울 리전 (필요에 따라 변경)
  .pubsub
  .schedule('0 0 * * *') // 매일 밤 12시 (UTC 기준)
  .timeZone('Asia/Seoul') // 한국 시간대
  .onRun(async (context) => {
    console.log('🧹 [Archive] 삭제된 계정 아카이브 작업 시작');

    const db = admin.firestore();
    const batchSize = 500; // Firestore Batch 제한
    let processedCount = 0;
    let errorCount = 0;

    try {
      // 7일 전 시간 계산
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      const sevenDaysAgoTimestamp = admin.firestore.Timestamp.fromDate(sevenDaysAgo);

      console.log(`📅 [Archive] 7일 전 시점: ${sevenDaysAgo.toISOString()}`);

      // isDeleted: true이고 deletedAt이 7일 이전인 사용자 조회
      const deletedUsersQuery = db
        .collection('users')
        .where('isDeleted', '==', true)
        .where('deletedAt', '<=', sevenDaysAgoTimestamp);

      let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
      let hasMore = true;

      while (hasMore) {
        let query = deletedUsersQuery.limit(batchSize);
        
        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();

        if (snapshot.empty) {
          hasMore = false;
          break;
        }

        console.log(`📦 [Archive] 처리할 계정 ${snapshot.size}개 발견`);

        // 배치 단위로 처리
        for (let i = 0; i < snapshot.docs.length; i += batchSize) {
          const batch = db.batch();
          const docs = snapshot.docs.slice(i, i + batchSize);

          for (const userDoc of docs) {
            try {
              const userId = userDoc.id;
              const userData = userDoc.data();

              console.log(`🔄 [Archive] 계정 처리 시작: ${userId}`);

              // deleted_users에 이미 존재하는지 확인
              const deletedUserRef = db.collection('deleted_users').doc(userId);
              const existingDeletedDoc = await deletedUserRef.get();

              if (existingDeletedDoc.exists) {
                console.log(`   ⚠️ [Archive] ${userId}는 이미 deleted_users에 존재함 (스킵)`);
                continue; // 이미 이동된 경우 스킵
              }

              // 1. 하위 컬렉션 데이터 읽기
              const [periodCyclesSnapshot, symptomsSnapshot] = await Promise.all([
                db.collection(`users/${userId}/periodCycles`).get(),
                db.collection(`users/${userId}/symptoms`).get(),
              ]);

              console.log(
                `   - 생리 주기: ${periodCyclesSnapshot.size}개, 증상: ${symptomsSnapshot.size}개`
              );

              // 2. deleted_users/{userId}에 사용자 데이터 복사
              batch.set(deletedUserRef, {
                ...userData,
                originalUid: userId,
                archivedAt: admin.firestore.FieldValue.serverTimestamp(), // 아카이브 시점
              });

              // 3. 생리 주기 데이터 복사 (원본은 유지)
              const deletedPeriodCyclesRef = deletedUserRef.collection('periodCycles');
              for (const periodDoc of periodCyclesSnapshot.docs) {
                batch.set(
                  deletedPeriodCyclesRef.doc(periodDoc.id),
                  periodDoc.data()
                );
                // 원본 삭제하지 않음 - 복사만 수행
              }

              // 4. 증상 데이터 복사 (원본은 유지)
              const deletedSymptomsRef = deletedUserRef.collection('symptoms');
              for (const symptomDoc of symptomsSnapshot.docs) {
                batch.set(
                  deletedSymptomsRef.doc(symptomDoc.id),
                  symptomDoc.data()
                );
                // 원본 삭제하지 않음 - 복사만 수행
              }

              // 5. users/{userId} 문서는 삭제하지 않음 (유지)
              // isDeleted: true 상태로 그대로 유지

              console.log(`   ✅ [Archive] ${userId} 아카이브 완료 (users 컬렉션은 유지)`);
            } catch (error) {
              console.error(`   ❌ [Archive] ${userDoc.id} 처리 실패:`, error);
              errorCount++;
            }
          }

          // Batch 실행
          if (batch._delegate._mutations.length > 0) {
            await batch.commit();
            processedCount += docs.length;
            console.log(`✅ [Archive] Batch 실행 완료: ${docs.length}개 처리`);
          }
        }

        // 다음 페이지로
        lastDoc = snapshot.docs[snapshot.docs.length - 1];
        hasMore = snapshot.size === batchSize;
      }

      console.log(
        `🎉 [Archive] 작업 완료 - 처리: ${processedCount}개, 오류: ${errorCount}개`
      );
    } catch (error) {
      console.error('❌ [Archive] 작업 실패:', error);
      throw error;
    }
  });

