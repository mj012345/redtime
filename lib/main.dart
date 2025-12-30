import 'package:flutter/material.dart';
import 'package:red_time_app/router/no_transition.dart';
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
      theme: ThemeData(primarySwatch: Colors.orange, fontFamily: 'Pretendard'),
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
