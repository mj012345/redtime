import 'package:flutter/material.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('리포트'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: const Center(child: Text('리포트 화면 (준비중)')),
      bottomNavigationBar: BottomNav(
        current: NavTab.report,
        onTap: (tab) {
          if (tab == NavTab.report) return;
          if (tab == NavTab.calendar) {
            Navigator.of(context).pushReplacementNamed('/calendar');
          } else {
            Navigator.of(context).pushReplacementNamed('/my');
          }
        },
      ),
      backgroundColor: Colors.white,
    );
  }
}
