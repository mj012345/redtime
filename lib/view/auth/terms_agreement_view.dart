import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_time_app/constants/terms_version.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/services/auth_service.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/view/terms/terms_page_view.dart';

class TermsAgreementView extends StatefulWidget {
  const TermsAgreementView({super.key});

  @override
  State<TermsAgreementView> createState() => _TermsAgreementViewState();
}

class _TermsAgreementViewState extends State<TermsAgreementView> {
  bool _allAgreed = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'RED TIME',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3D3A3A),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'better routine for your period',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6D5454),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl * 2),
                Text(
                  '서비스 이용을 위해\n약관에 동의해주세요',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // 전체 동의
                _buildCheckbox(
                  value: _allAgreed,
                  label: '전체 동의',
                  onChanged: (value) {
                    setState(() {
                      _allAgreed = value ?? false;
                      _termsAgreed = _allAgreed;
                      _privacyAgreed = _allAgreed;
                    });
                  },
                  isBold: true,
                ),
                const Divider(height: AppSpacing.xl),
                // 이용약관 동의
                _buildCheckbox(
                  value: _termsAgreed,
                  label: '이용약관 동의 (필수)',
                  onChanged: (value) {
                    setState(() {
                      _termsAgreed = value ?? false;
                      _allAgreed = _termsAgreed && _privacyAgreed;
                    });
                  },
                  onLinkTap: () {
                    Navigator.of(context).pushNamed(
                      '/terms-page',
                      arguments: {'type': TermsPageType.terms},
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // 개인정보처리방침 동의
                _buildCheckbox(
                  value: _privacyAgreed,
                  label: '개인정보처리방침 동의 (필수)',
                  onChanged: (value) {
                    setState(() {
                      _privacyAgreed = value ?? false;
                      _allAgreed = _termsAgreed && _privacyAgreed;
                    });
                  },
                  onLinkTap: () {
                    Navigator.of(context).pushNamed(
                      '/privacy-page',
                      arguments: {'type': TermsPageType.privacy},
                    );
                  },
                ),
                const Spacer(),
                // 동의하고 시작하기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: (_termsAgreed && _privacyAgreed)
                        ? () => _handleAgreement(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.textDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '동의하고 시작하기',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
    VoidCallback? onLinkTap,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onLinkTap,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: onLinkTap != null
                    ? AppColors.primary
                    : AppColors.textPrimary,
                decoration: onLinkTap != null
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAgreement(BuildContext context) async {
    try {
      // 1. 약관 동의 정보 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terms_agreed', true);
      await prefs.setString(
        'terms_agreed_at',
        DateTime.now().toIso8601String(),
      );

      // 2. 신규 회원인 경우 Firestore에 사용자 정보 저장
      final authService = AuthService();
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        try {
          // Firestore에서 사용자 정보 확인 (이미 저장되어 있는지)
          final existingUser = await authService.getUserFromFirestore(
            currentUser.uid,
          );
          if (existingUser == null) {
            // 신규 회원: 약관 동의 후 Firestore에 저장 (약관 버전 정보 포함)
            final newUserModel = UserModel(
              uid: currentUser.uid,
              email: currentUser.email ?? '',
              displayName: null,
              photoURL: null,
              termsVersion: TermsVersion.termsVersion,
              privacyVersion: TermsVersion.privacyVersion,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await authService.saveUserToFirestore(newUserModel);
          }
        } catch (e) {
          debugPrint('신규 회원 Firestore 저장 실패: $e');
          // 저장 실패해도 약관 동의는 완료된 것으로 처리
        }
      }

      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/calendar');
      }
    } catch (e) {
      debugPrint('약관 동의 처리 실패: $e');
      // 저장 실패 시에도 달력 화면으로 이동 (다음에 다시 표시됨)
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/calendar');
      }
    }
  }
}
