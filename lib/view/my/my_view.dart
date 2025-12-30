import 'package:flutter/material.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';

class MyView extends StatelessWidget {
  const MyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: const Center(child: Text('MY 화면 (준비중)')),
      bottomNavigationBar: BottomNav(
        current: NavTab.my,
        onTap: (tab) {
          if (tab == NavTab.my) return;
          if (tab == NavTab.calendar) {
            Navigator.of(context).pushReplacementNamed('/calendar');
          } else {
            Navigator.of(context).pushReplacementNamed('/report');
          }
        },
      ),
      backgroundColor: Colors.white,
    );
  }
}
