import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/widgets/common_dialog.dart';

class SplashView extends StatefulWidget {
  final bool showOnlyUI;
  const SplashView({super.key, this.showOnlyUI = false});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    
    // 2초 동안 천천히 반복되는 부드러운 애니메이션
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // 1. Scale (Breathing) - 조금 더 선명하게
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 2. Opacity (Breathing)
    _opacityAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 3. Floating (Up & Down) - 이동 범위 확대
    _floatingAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: const Offset(0, -0.05),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // UI 모드가 아닐 때만 네트워크 체크 및 초기화 진행
    if (!widget.showOnlyUI) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNetworkAndInitialize();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkNetworkAndInitialize() async {
    try {
      // 최소 2.5초 대기 (애니메이션을 충분히 보여주기 위해 약간 늘림)
      final results = await Future.wait([
        InternetAddress.lookup('google.com'),
        Future.delayed(const Duration(milliseconds: 2500)),
      ]);

      final networkResult = results[0] as List<InternetAddress>;

      if (networkResult.isNotEmpty && networkResult[0].rawAddress.isNotEmpty) {
        if (mounted) {
          final authVm = Provider.of<AuthViewModel>(context, listen: false);
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
      builder: (context) => AppAlertDialog(
        title: '네트워크 오류',
        content: '네트워크 연결을 확인해 주세요.',
        confirmLabel: '재시도',
        showCancel: false,
        onConfirm: () {
          Navigator.of(context).pop();
          _checkNetworkAndInitialize();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation, // 2. Breathing (Opacity)
          child: SlideTransition(
            position: _floatingAnimation, // 1. Floating (Slide)
            child: ScaleTransition(
              scale: _scaleAnimation, // 2. Breathing (Scale)
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/icons/redtime_logo_vertical.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
