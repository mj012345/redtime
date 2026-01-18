import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    // 화면이 그려진 후 네트워크 체크 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNetworkAndInitialize();
    });
  }

  Future<void> _checkNetworkAndInitialize() async {
    try {
      // 최소 2초 대기 + 네트워크 체크 동시 진행
      final results = await Future.wait([
        InternetAddress.lookup('google.com'),
        Future.delayed(const Duration(seconds: 2)),
      ]);

      final networkResult = results[0] as List<InternetAddress>;

      if (networkResult.isNotEmpty && networkResult[0].rawAddress.isNotEmpty) {
        // 네트워크 연결 성공 -> ViewModel 초기화 시작
        if (mounted) {
          final authVm = Provider.of<AuthViewModel>(context, listen: false);
          // 초기 상태이거나 에러 상태인 경우 초기화 시작
          if (authVm.state is AuthUninitialized || authVm.state is AuthError) {
             authVm.initialize();
          }
        }
      } else {
        _showNetworkErrorDialog();
      }
    } on SocketException catch (_) {
      _showNetworkErrorDialog();
    }
  }

  void _showNetworkErrorDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('네트워크 오류'),
        content: const Text('네트워크 연결을 확인해 주세요.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkNetworkAndInitialize(); // 재시도
            },
            child: const Text('재시도'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 (예시)
            Text(
              'RED TIME',
              style: AppTextStyles.title.copyWith(
                fontSize: 40,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
