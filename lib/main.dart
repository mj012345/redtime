import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/repositories/period_repository.dart';
import 'package:red_time_app/repositories/symptom_repository.dart';
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
        // 사용자 ID 기반으로 CalendarViewModel 생성
        ChangeNotifierProxyProvider<AuthViewModel, CalendarViewModel>(
          create: (_) => CalendarViewModel(), // 초기 생성
          update: (context, authVm, previous) {
            final userId = authVm.currentUser?.uid;
            print('🔄 [MyApp] CalendarViewModel 업데이트 - 사용자 ID: $userId');

            // 이전 인스턴스가 있고 사용자 ID가 같으면 재사용
            if (previous != null && previous.userId == userId) {
              print('♻️ [MyApp] 기존 CalendarViewModel 재사용 (같은 사용자: $userId)');
              return previous;
            }

            if (userId != null) {
              // Firebase Repository 사용
              print(
                '✅ [MyApp] Firebase Repository로 CalendarViewModel 생성 - 사용자 ID: $userId',
              );
              final periodRepo = FirebasePeriodRepository(userId);
              final symptomRepo = FirebaseSymptomRepository(userId);

              return CalendarViewModel(
                periodRepository: periodRepo,
                symptomRepository: symptomRepo,
              );
            } else {
              // 로그인 안 된 경우 메모리 Repository 사용
              print('⚠️ [MyApp] InMemory Repository로 CalendarViewModel 생성');
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
        print('👤 [AuthWrapper] 현재 로그인된 사용자 ID: ${user.uid}');
        print('👤 [AuthWrapper] 이메일: ${user.email}');
        print('👤 [AuthWrapper] 이름: ${user.displayName}');
        print('🔍 [AuthWrapper] 사용자 유효성 검증 시작...');

        try {
          // 사용자 정보 갱신 (Firebase에서 삭제되었는지 확인)
          await user.reload();
          print('✅ [AuthWrapper] 사용자 정보 갱신 완료');

          // 갱신된 사용자 정보 가져오기
          final updatedUser = FirebaseAuth.instance.currentUser;
          if (updatedUser == null) {
            print('⚠️ [AuthWrapper] 사용자가 삭제되었습니다. 로그아웃 처리합니다.');
            await FirebaseAuth.instance.signOut();
            setState(() {
              _isValidating = false;
              _isValidUser = false;
            });
            return;
          }

          // 토큰 유효성 확인
          try {
            await updatedUser.getIdToken(true); // 강제 갱신
            print('✅ [AuthWrapper] 사용자 토큰 유효성 확인 완료: ${updatedUser.uid}');
            setState(() {
              _isValidating = false;
              _isValidUser = true;
            });
          } catch (e) {
            print('❌ [AuthWrapper] 토큰 유효성 확인 실패: $e');
            print('⚠️ [AuthWrapper] 사용자가 유효하지 않습니다. 로그아웃 처리합니다.');
            await FirebaseAuth.instance.signOut();
            setState(() {
              _isValidating = false;
              _isValidUser = false;
            });
          }
        } catch (e, stackTrace) {
          print('❌ [AuthWrapper] 사용자 유효성 검증 실패: $e');
          print('❌ [AuthWrapper] Stack trace: $stackTrace');
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
        print('👤 [AuthWrapper] 로그인된 사용자 없음');
        setState(() {
          _isValidating = false;
          _isValidUser = false;
        });
      }
    } catch (e) {
      print('❌ [AuthWrapper] Firebase 인스턴스 접근 실패: $e');
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
          if (snapshot.hasData && snapshot.data != null) {
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
