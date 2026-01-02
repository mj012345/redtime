import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/router/no_transition.dart';
import 'package:red_time_app/services/firebase_service.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/view/auth/login_view.dart';
import 'package:red_time_app/view/calendar/calendar_view.dart';
import 'package:red_time_app/view/calendar/calendar_viewmodel.dart';
import 'package:red_time_app/view/my/my_view.dart';
import 'package:red_time_app/view/report/report_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  final initialized = await FirebaseService.initialize();
  if (!initialized) {
    print('경고: Firebase 초기화에 실패했습니다. ${FirebaseService.errorMessage}');
    // 초기화 실패해도 앱은 실행 (checkInitialized()에서 재시도)
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
        ChangeNotifierProvider(create: (_) => CalendarViewModel()),
      ],
      child: MaterialApp(
        title: 'Period Tracker',
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
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              return noTransition(const LoginView());
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
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Firebase 초기화 확인
    if (!FirebaseService.checkInitialized()) {
      // Firebase 초기화 실패 시 로그인 화면 표시
      // (iOS의 경우 GoogleService-Info.plist가 필요할 수 있음)
      return const LoginView();
    }

    try {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 로그인 상태 확인
          if (snapshot.hasData && snapshot.data != null) {
            // 로그인됨: 달력 화면으로
            return const FigmaCalendarPage();
          } else {
            // 로그인 안됨: 로그인 화면으로
            return const LoginView();
          }
        },
      );
    } catch (e) {
      // Firebase 인스턴스 접근 실패 시 로그인 화면 표시
      print('FirebaseAuth 인스턴스 접근 실패: $e');
      return const LoginView();
    }
  }
}
