import 'package:flutter/material.dart';
import 'package:red_time_app/new.dart';

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
      // home: const PeriodTrackerScreen(),
      home: const FigmaCalendarPage(),
    );
  }
}
