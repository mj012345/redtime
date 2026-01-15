import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/firebase_options.dart';
import 'package:red_time_app/repositories/period_repository.dart';
import 'package:red_time_app/repositories/symptom_repository.dart';
import 'package:red_time_app/router/no_transition.dart';
import 'package:red_time_app/services/firebase_service.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/view/auth/login_view.dart';
import 'package:red_time_app/view/auth/signup_complete_view.dart';
import 'package:red_time_app/view/auth/terms_agreement_view.dart';
import 'package:red_time_app/view/terms/terms_page_view.dart';
import 'package:red_time_app/view/calendar/calendar_view.dart';
import 'package:red_time_app/view/calendar/calendar_viewmodel.dart';
import 'package:red_time_app/view/my/my_view.dart';
import 'package:red_time_app/view/report/report_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 전역 에러 핸들러 설정 (빨간 에러 화면 방지)
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('전역 에러: ${details.exception}');
    debugPrint('스택: ${details.stack}');
    // FlutterError.presentError()를 호출하지 않아 빨간 화면이 나타나지 않음
    // release 모드에서도 작동하도록 처리
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  // 플랫폼 예외 핸들러
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('플랫폼 에러: $error');
    debugPrint('스택: $stack');
    return true; // 에러 처리됨
  };

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
    // 초기화 실패해도 앱은 실행 (FirebaseService.checkInitialized()에서 재시도)
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        // 사용자 ID 기반으로 CalendarViewModel 생성
        ChangeNotifierProxyProvider<AuthViewModel, CalendarViewModel>(
          create: (_) => CalendarViewModel(), // 초기 생성
          update: (context, authVm, previous) {
            final userId = authVm.currentUser?.uid;
            final previousUserId = previous?.userId;

            // 로그아웃 중인 경우 (userId가 null이고 이전에 userId가 있었던 경우)
            // 또는 로그아웃 완료된 경우 (userId가 null이고 이전에도 null인 경우)
            if (userId == null) {
              // 로그인 안 된 경우 메모리 Repository 사용
              // 이전 인스턴스가 있으면 dispose하고 새로 생성
              if (previous != null && previous.userId != null) {
                debugPrint(
                  '🔄 [CalendarViewModel] 로그아웃 감지 - 메모리 Repository로 전환',
                );
              }
              return CalendarViewModel();
            }

            // 수동 로그인 vs 자동 로그인 구분
            // 수동 로그인: 사용자가 명시적으로 로그인 버튼 클릭 → forceRefresh: true (서버에서 가져오기)
            // 자동 로그인: 앱 재시작 시 Firebase Auth persistence로 세션 복원 → forceRefresh: false (캐시 사용)
            final isNewLogin = authVm.isManualLogin;

            // 사용자 ID가 변경되었거나, 새 로그인인 경우 새로운 인스턴스 생성
            if (previousUserId != userId || isNewLogin) {
              debugPrint(
                '🔄 [CalendarViewModel] 새 인스턴스 생성: userId=$userId, isNewLogin=$isNewLogin',
              );
              // Firebase Repository 사용
              final periodRepo = FirebasePeriodRepository(userId);
              final symptomRepo = FirebaseSymptomRepository(userId);

              final viewModel = CalendarViewModel(
                periodRepository: periodRepo,
                symptomRepository: symptomRepo,
                isNewLogin: isNewLogin,
              );

              // 달력 화면 진입 시점에 사용자 데이터 동기화
              // authStateChanges 리스너가 완료될 때까지 대기 후 동기화
              Future.microtask(() async {
                // authStateChanges 리스너가 userModel을 설정할 때까지 최대 3초 대기
                final maxWaitTime = const Duration(seconds: 3);
                final startTime = DateTime.now();

                while (authVm.currentUser == null || authVm.userModel == null) {
                  if (DateTime.now().difference(startTime) > maxWaitTime) {
                    debugPrint(
                      '⏰ [CalendarViewModel] 사용자 데이터 대기 타임아웃 - 동기화 생략',
                    );
                    return;
                  }
                  await Future.delayed(const Duration(milliseconds: 100));
                }

                debugPrint('🔄 [CalendarViewModel] 달력 화면 진입 - 사용자 데이터 동기화 시작');
                final syncSuccess = await authVm.syncUserDataToFirestore();
                if (syncSuccess) {
                  debugPrint('✅ [CalendarViewModel] 사용자 데이터 동기화 완료');
                } else {
                  debugPrint('⚠️ [CalendarViewModel] 사용자 데이터 동기화 실패 (계속 진행)');
                }
              });

              // 수동 로그인 플래그 리셋 (한 번만 적용되도록)
              if (isNewLogin) {
                authVm.resetManualLoginFlag();
              }

              return viewModel;
            } else {
              // 동일 사용자이고 새 로그인이 아닌 경우 (앱 재시작 등), 기존 인스턴스 재사용
              debugPrint('🔄 [CalendarViewModel] 기존 인스턴스 재사용: userId=$userId');
              return previous!;
            }
          },
        ),
      ],
      child: MaterialApp(
        title: 'Period Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Pretendard',
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            background: AppColors.background,
            surface: AppColors.surface,
          ),
          textTheme: TextTheme(
            titleLarge: AppTextStyles.title,
            bodyMedium: AppTextStyles.body,
            bodySmall: AppTextStyles.caption,
          ),
        ),
        // 에러 발생 시 빨간 화면 대신 에러 메시지 표시
        builder: (context, child) {
          Widget errorWidget = child ?? const SizedBox();
          // 에러 발생 시 처리
          return MediaQuery(data: MediaQuery.of(context), child: errorWidget);
        },
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return noTransition(const LoginView());
            case '/terms':
              return noTransition(const TermsAgreementView());
            case '/signup-complete':
              return noTransition(const SignupCompleteView());
            case '/terms-page':
            case '/privacy-page':
              final args = settings.arguments as Map<String, dynamic>?;
              final type = args?['type'] as TermsPageType?;
              if (type != null) {
                return noTransition(TermsPageView(type: type));
              }
              return noTransition(const TermsAgreementView());
            case '/report':
              return noTransition(const ReportView());
            case '/my':
              return noTransition(const MyView());
            case '/calendar':
            default:
              return noTransition(const FigmaCalendarPage());
          }
        },
      ),
    );
  }
}

/// 로그인 상태에 따라 화면 전환
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isValidating = true;
  bool _isValidUser = false;

  @override
  void initState() {
    super.initState();
    _validateUser();
  }

  /// 사용자 유효성 검증
  Future<void> _validateUser() async {
    debugPrint('🔍 [AuthWrapper] 사용자 유효성 검증 시작');
    // Firebase 초기화 확인
    if (!FirebaseService.checkInitialized()) {
      debugPrint('❌ [AuthWrapper] Firebase 미초기화 - 로그인 화면 표시');
      setState(() {
        _isValidating = false;
        _isValidUser = false;
      });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint(
        '🔍 [AuthWrapper] FirebaseAuth.instance.currentUser 확인: ${user?.uid ?? "null"}',
      );
      if (user != null) {
        debugPrint('✅ [AuthWrapper] 기존 로그인 세션 발견 - 사용자 정보 검증 시작');
        try {
          // 사용자 정보 갱신 (Firebase에서 삭제되었는지 확인)
          // 타임아웃 추가하여 무한 대기 방지
          await user.reload().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('사용자 정보 갱신 타임아웃');
            },
          );

          // 갱신된 사용자 정보 가져오기
          final updatedUser = FirebaseAuth.instance.currentUser;
          if (updatedUser == null) {
            await FirebaseAuth.instance.signOut();
            setState(() {
              _isValidating = false;
              _isValidUser = false;
            });
            return;
          }

          // 토큰 유효성 확인 (타임아웃 추가)
          try {
            await updatedUser
                .getIdToken(true)
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () {
                    debugPrint('토큰 갱신 타임아웃');
                    throw TimeoutException('토큰 갱신 타임아웃');
                  },
                );
            debugPrint('✅ [AuthWrapper] 사용자 검증 성공 - 자동 로그인 (세션 유지)');
            setState(() {
              _isValidating = false;
              _isValidUser = true;
            });
          } catch (e) {
            debugPrint('❌ [AuthWrapper] 토큰 검증 실패 - 로그아웃 처리: $e');
            await FirebaseAuth.instance.signOut();
            setState(() {
              _isValidating = false;
              _isValidUser = false;
            });
          }
        } catch (e) {
          // 에러 발생 시 로그아웃 처리
          debugPrint('❌ [AuthWrapper] 사용자 정보 갱신 실패 - 로그아웃 처리: $e');
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
          setState(() {
            _isValidating = false;
            _isValidUser = false;
          });
        }
      } else {
        debugPrint('ℹ️ [AuthWrapper] 기존 로그인 세션 없음 - 로그인 화면 표시');
        setState(() {
          _isValidating = false;
          _isValidUser = false;
        });
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
        _isValidUser = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 검증 중
    if (_isValidating) {
      debugPrint('🔄 [AuthWrapper] 사용자 검증 중...');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 검증 완료 후 화면 전환
    if (_isValidUser) {
      debugPrint('✅ [AuthWrapper] 사용자 검증 완료 - authStateChanges 스트림 구독 시작');
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          debugPrint('📡 [AuthWrapper] authStateChanges 이벤트 수신');
          debugPrint('  - hasData: ${snapshot.hasData}');
          debugPrint('  - hasError: ${snapshot.hasError}');
          debugPrint('  - connectionState: ${snapshot.connectionState}');

          // 스트림이 아직 데이터를 기다리는 중이면 로딩 화면 표시
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('🔄 [AuthWrapper] authStateChanges 대기 중...');
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 에러 발생 시 로그인 화면으로 이동
          if (snapshot.hasError) {
            debugPrint(
              '❌ [AuthWrapper] authStateChanges Stream 에러: ${snapshot.error}',
            );
            debugPrint('❌ [AuthWrapper] 로그인 화면으로 전환');
            return const LoginView();
          }

          // 스트림이 활성 상태이고 데이터가 있는 경우
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData && snapshot.data != null) {
              final user = snapshot.data!;
              debugPrint('✅ [AuthWrapper] 로그인된 사용자 감지: ${user.uid}');
              debugPrint('✅ [AuthWrapper] 달력 화면으로 전환');
              // 로그인된 사용자는 달력 화면으로 (약관 동의는 로그인 후 처리)
              return const FigmaCalendarPage();
            } else {
              debugPrint('❌ [AuthWrapper] 로그인되지 않음 - 로그인 화면으로 전환');
              return const LoginView();
            }
          }

          // 기타 상태 (done 등) - 기본적으로 로딩 화면 표시
          debugPrint(
            '🔄 [AuthWrapper] authStateChanges 기타 상태: ${snapshot.connectionState}',
          );
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    } else {
      debugPrint('❌ [AuthWrapper] 사용자 검증 실패 - 로그인 화면 표시');
      return const LoginView();
    }
  }
}
