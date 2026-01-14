import 'package:flutter/material.dart';
import 'package:red_time_app/constants/terms_version.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';

/// 약관 페이지 타입
enum TermsPageType {
  terms, // 이용약관
  privacy, // 개인정보처리방침
}

/// 약관 페이지 뷰
class TermsPageView extends StatelessWidget {
  final TermsPageType type;

  const TermsPageView({super.key, required this.type});

  String get _title {
    switch (type) {
      case TermsPageType.terms:
        return '이용약관';
      case TermsPageType.privacy:
        return '개인정보처리방침';
    }
  }

  String get _version {
    switch (type) {
      case TermsPageType.terms:
        return TermsVersion.termsVersion;
      case TermsPageType.privacy:
        return TermsVersion.privacyVersion;
    }
  }

  String get _content {
    // TODO: 약관 내용을 여기에 추가 예정
    switch (type) {
      case TermsPageType.terms:
        return '이용약관 내용이 여기에 표시됩니다.\n\n버전: $_version';
      case TermsPageType.privacy:
        return '개인정보처리방침 내용이 여기에 표시됩니다.\n\n버전: $_version';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: AppColors.textPrimary,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDF7F7), Color(0xFFF4E1DF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '시행일: ${DateTime.now().toString().split(' ')[0]}\n버전: $_version',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _content,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.6,
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
