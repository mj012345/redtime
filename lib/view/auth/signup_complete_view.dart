import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

/// 회원가입 완료 화면
class SignupCompleteView extends StatelessWidget {
  const SignupCompleteView({super.key});

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
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 100),
                // 타이틀
                Text(
                  '환영합니다!',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: AppSpacing.xs),
                // 설명 텍스트
                Text(
                  '레드타임과 함께 건강한 변화를 시작해 보세요.',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 50),
                // 체크 아이콘
                // 완료 로티 애니메이션
                Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Lottie.asset(
                      'assets/Congratulations.json',
                      fit: BoxFit.contain,
                      repeat: false,
                      delegates: LottieDelegates(
                        values: [
                          ValueDelegate.color(
                            // 모든 Fill 1 (채우기) 레이어의 색상을 변경
                            const ['**', 'Fill 1', '**'],
                            value: AppColors.primary,
                          ),
                          ValueDelegate.color(
                            // 모든 Stroke 1 (선) 레이어의 색상을 변경 (필요한 경우)
                            const ['**', 'Stroke 1', '**'],
                            value: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // 홈화면으로 이동 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/calendar');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '홈화면으로 이동',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
