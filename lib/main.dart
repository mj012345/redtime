import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemChrome 사용을 위한 임포트
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
import 'package:red_time_app/view/splash/splash_view.dart';
import 'package:red_time_app/view/terms/terms_page_view.dart';
import 'package:red_time_app/view/calendar/calendar_view.dart';
import 'package:red_time_app/view/calendar/calendar_viewmodel.dart';
import 'package:red_time_app/view/my/my_view.dart';
import 'package:red_time_app/view/report/report_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 화면 방향을 세로(portraitUp)로 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 전역 에러 핸들러 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    return true; 
  };

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseService.initialize();
  } catch (e) {
    // 초기화 실패해도 앱은 실행
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
          create: (_) => CalendarViewModel(),
          update: (context, authVm, previous) {
            final currentUser = authVm.currentUser;
            final userId = currentUser?.uid;
            
            // 로그인 안 된 경우 메모리 Repository 사용
            if (userId == null) {
              return CalendarViewModel();
            }

            // 단순화된 로직: userId가 바뀌면 무조건 새로 생성
            // 단, previous가 있고 같은 userId라면 재사용
            if (previous != null && previous.userId == userId) {
              return previous;
            }

            // 새로운 로그인 (또는 앱 시작)
            final periodRepo = FirebasePeriodRepository(userId);
            final symptomRepo = FirebaseSymptomRepository(userId);
            
            return CalendarViewModel(
                periodRepository: periodRepo,
                symptomRepository: symptomRepo,
                isNewLogin: true, 
            );
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
            surface: AppColors.surface,
          ),
          textTheme: TextTheme(
            titleLarge: AppTextStyles.title,
            bodyMedium: AppTextStyles.body,
            bodySmall: AppTextStyles.caption,
          ),
        ),
        builder: (context, child) {
          Widget errorWidget = child ?? const SizedBox();
          return MediaQuery(data: MediaQuery.of(context), child: errorWidget);
        },
        // State-Driven Navigation
        home: Consumer<AuthViewModel>(
          builder: (context, authVm, child) {
            final state = authVm.state;
            
            return switch (state) {
              AuthUninitialized() || AuthLoading() => const SplashView(), // 스플래시 화면 연결
              Unauthenticated() => const LoginView(),
              AuthError(message: final msg) => LoginView(errorMessage: msg),
              Authenticated(isNewUser: final isNewUser) => isNewUser
                  ? const TermsAgreementView() 
                  : const CalendarView(),
            };
          },
        ),
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
              return noTransition(const CalendarView());
          }
        },
      ),
    );
  }
}
