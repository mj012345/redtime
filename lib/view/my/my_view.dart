import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';

class MyView extends StatelessWidget {
  const MyView({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    // 확인 다이얼로그 표시
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && context.mounted) {
      await authViewModel.signOut();

      // 로그아웃 완료 후 로그인 페이지로 이동
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: Column(
        children: [
          const Expanded(child: Center(child: Text('MY 화면 (준비중)'))),
          // 로그아웃 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleSignOut(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('로그아웃'),
              ),
            ),
          ),
        ],
      ),
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
