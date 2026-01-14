import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

/// 인터넷 연결 오류 화면
class OfflineView extends StatelessWidget {
  const OfflineView({super.key});

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
                  // 아이콘
                  Icon(
                    Icons.warning_rounded,
                    size: 64,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // 메시지
                  Text(
                    '인터넷이 연결되어 있지 않아요',
                    style: AppTextStyles.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // 다시 시도하기 버튼
                  ElevatedButton(
                    onPressed: () {
                      // 직전 화면으로 돌아가서 새로고침
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '다시 시도하기',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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
