import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/view/auth/widgets/social_login_button.dart';

/// 구글 로그인 화면
class LoginView extends StatefulWidget {
  final String? errorMessage;
  const LoginView({super.key, this.errorMessage});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.errorMessage!)),
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant LoginView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != null && widget.errorMessage != oldWidget.errorMessage) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.errorMessage!)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = Provider.of<AuthViewModel>(context);
    // 상태가 로딩 중인지 확인 (AuthLoading 상태이거나 수동 로그인 로딩)
    final isLoading = authVm.state is AuthLoading || authVm.isManualLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFBF9F5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/redtime_logo_horizontal.png',
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'better routine for your period',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6D5454),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 100),
                  Text(
                    'sns 간편 로그인',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 16,
                      color: const Color(0xFFB09A9A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Google 로그인 버튼
                  SocialLoginButton(
                    label: '구글 로그인',
                    icon: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10), // 20x20의 절반인 10으로 수정
                      ),
                      child: Center(
                        child: Image.network(
                          'https://developers.google.com/identity/images/g-logo.png',
                          width: 14, // 컨테이너(20)보다 약간 작게 설정하여 여백 확보
                          height: 14,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.g_mobiledata,
                                color: Color(0xFF4285F4),
                                size: 18, // 컨테이너 크기에 맞춰 조절
                              ),
                        ),
                      ),
                    ),
                    onPressed: () {
                      authVm.signInWithGoogle();
                    },
                    isLoading: isLoading,
                    backgroundColor: Colors.white,
                    borderColor: const Color(0xFFE0E0E0),
                    textColor: const Color(0xFF3D3A3A),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
