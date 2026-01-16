import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/widgets/social_login_button.dart';

/// 구글 로그인 화면
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDF7F7), Color(0xFFF4E1DF)],
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
                  Text(
                    'RED TIME',
                    style: AppTextStyles.title.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3D3A3A),
                    ),
                    textAlign: TextAlign.center,
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
                  const SizedBox(height: 5),
                  // Google 로그인 버튼
                  SocialLoginButton(
                    label: '구글 로그인',
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.network(
                        'https://developers.google.com/identity/images/g-logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.g_mobiledata,
                              color: Color(0xFF4285F4),
                              size: 26,
                            ),
                      ),
                    ),
                    onPressed: () {
                      // Google 로그인 버튼 클릭 시 약관 동의 화면으로 이동
                      Navigator.of(context).pushReplacementNamed('/terms');
                    },
                    isLoading: false,
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
