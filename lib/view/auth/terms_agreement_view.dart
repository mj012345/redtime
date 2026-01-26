import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/constants/terms_version.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAgreementView extends StatefulWidget {
  const TermsAgreementView({super.key});

  @override
  State<TermsAgreementView> createState() => _TermsAgreementViewState();
}

class _TermsAgreementViewState extends State<TermsAgreementView> {
  bool _allAgreed = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _isLoading = false;

  /// 뒤로가기: 로그인 화면으로 이동
  void _handleBack() {
    context.read<AuthViewModel>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textPrimary,
          onPressed: _handleBack,
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
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '서비스 이용을 위한\n약관 동의가 필요해요',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        const SizedBox(height: AppSpacing.xs),
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
                          onLinkTap: () async {
                            final url = Uri.parse(TermsVersion.termsUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.xs),
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
                          onLinkTap: () async {
                            final url = Uri.parse(TermsVersion.privacyUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // 동의하고 시작하기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_termsAgreed && _privacyAgreed && !_isLoading)
                        ? () => _handleAgreement(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.textDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            '동의하고 시작하기',
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

  Widget _buildCheckbox({
    required bool value,
    required String label,
    required ValueChanged<bool?> onChanged,
    VoidCallback? onLinkTap,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onLinkTap,
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontSize: isBold ? 18 : 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
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
        SizedBox(
          width: 32, // 고정 너비를 확보하여 정렬 기준 마련
          child: Align(
            alignment: Alignment.centerRight,
            child: isBold 
              ? Transform.scale(
                  scale: 1.1,
                  alignment: Alignment.centerRight, // 오른쪽 기준으로 스케일 조정
                  child: Checkbox(
                    value: value,
                    onChanged: onChanged,
                    activeColor: AppColors.primary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                    side: BorderSide(color: AppColors.textPrimary, width: 1.5),
                  ),
                )
              : Transform.scale(
                  scale: 1.0,
                  alignment: Alignment.centerRight, // 오른쪽 기준으로 스케일 조정
                  child: Checkbox(
                    value: value,
                    onChanged: onChanged,
                    activeColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.5), width: 1.0),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAgreement(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();

      // 1. 약관 동의 내용 로컬 저장 (선택 사항, 캐시용)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('terms_agreed', true);
        await prefs.setString(
          'terms_agreed_at',
          DateTime.now().toIso8601String(),
        );
      } catch (_) {}

      // 2. ViewModel을 통해 정회원 전환 (DB 저장 및 상태 업데이트)
      // 이미 구글 로그인이 완료된 상태이므로 다시 로그인할 필요 없음
      final success = await authViewModel.convertToRegisteredUser();

      if (!context.mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // 성공 시 상태가 자동으로 SignupCompleteView로 전환됨
        // (AuthViewModel에서 showCompletionScreen: true로 설정)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입 처리에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
