import 'package:flutter/material.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

/// 소셜 로그인 버튼 위젯
class SocialLoginButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color? loadingIndicatorColor;

  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.loadingIndicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor),
          padding: EdgeInsets.zero, // 버튼 내부 기본 패딩 제거하여 Row가 중앙에 오도록 함
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: loadingIndicatorColor ?? textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center, // 텍스트와 아이콘 수직 정렬 명시
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.0, // 텍스트 줄높이를 1.0으로 설정하여 수직 중앙 맞춤 보조
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

