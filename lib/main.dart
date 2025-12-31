import 'package:flutter/material.dart';
import 'package:red_time_app/router/no_transition.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/calendar/calendar_view.dart';
import 'package:red_time_app/view/my/my_view.dart';
import 'package:red_time_app/view/report/report_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      initialRoute: '/calendar',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/report':
            return noTransition(const ReportView());
          case '/my':
            return noTransition(const MyView());
          case '/calendar':
          default:
            return noTransition(const FigmaCalendarPage());
        }
      },
    );
  }
}
