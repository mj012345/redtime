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
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor),
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
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

