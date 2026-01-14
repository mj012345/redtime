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

            // 이전 인스턴스가 있고 사용자 ID가 같으면 재사용
            if (previous != null && previous.userId == userId) {
              return previous;
            }

            if (userId != null) {
              // Firebase Repository 사용
              final periodRepo = FirebasePeriodRepository(userId);
              final symptomRepo = FirebaseSymptomRepository(userId);

              return CalendarViewModel(
                periodRepository: periodRepo,
                symptomRepository: symptomRepo,
              );
            } else {
              // 로그인 안 된 경우 메모리 Repository 사용
              // 이전 인스턴스가 InMemory였으면 재사용
              if (previous != null && previous.userId == null) {
                return previous;
              }
              return CalendarViewModel();
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
    // Firebase 초기화 확인
    if (!FirebaseService.checkInitialized()) {
      setState(() {
        _isValidating = false;
        _isValidUser = false;
      });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
            setState(() {
              _isValidating = false;
              _isValidUser = true;
            });
          } catch (e) {
            await FirebaseAuth.instance.signOut();
            setState(() {
              _isValidating = false;
              _isValidUser = false;
            });
          }
        } catch (e) {
          // 에러 발생 시 로그아웃 처리
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
          setState(() {
            _isValidating = false;
            _isValidUser = false;
          });
        }
      } else {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 검증 완료 후 화면 전환
    if (_isValidUser) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 에러 발생 시 로그인 화면으로 이동
          if (snapshot.hasError) {
            debugPrint('authStateChanges Stream 에러: ${snapshot.error}');
            return const LoginView();
          }

          if (snapshot.hasData && snapshot.data != null) {
            // 로그인된 사용자는 달력 화면으로 (약관 동의는 로그인 후 처리)
            return const FigmaCalendarPage();
          } else {
            return const LoginView();
          }
        },
      );
    } else {
      return const LoginView();
    }
  }
}
