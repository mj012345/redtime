import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';

class MyView extends StatelessWidget {
  const MyView({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    // 확인 다이얼로그 표시
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black.withValues(alpha: 0.5),
            ),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true && context.mounted) {
      await authViewModel.signOut();

      // 로그아웃 완료 후 로그인 페이지로 이동
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 현재 특별한 리프레시 로직 없음
          // 추후 사용자 정보 갱신 등에 사용할 수 있도록 구조만 추가
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Consumer<AuthViewModel>(
                  builder: (context, authViewModel, _) {
                    final userModel = authViewModel.userModel;
                    final displayName = userModel?.displayName ?? '이름 없음';
                    final email = userModel?.email ?? '';

                    return IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          // 사용자 정보 카드
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '내정보',
                                  style: AppTextStyles.title.copyWith(
                                    fontSize: 16,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                // 이름
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                // 이메일
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // 로그아웃 버튼 (하단 고정, 밑줄 스타일)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: 40,
                              top: AppSpacing.xl,
                            ),
                            child: Center(
                              child: TextButton(
                                onPressed: () => _handleSignOut(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                                child: Text(
                                  '로그아웃',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textDisabled,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.textDisabled,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNav(
        current: NavTab.my,
        onTap: (tab) {
          if (tab == NavTab.my) return;
          if (tab == NavTab.calendar) {
            Navigator.of(context).pushReplacementNamed('/calendar');
          } else {
            Navigator.of(context).pushReplacementNamed('/report');
          }
        },
      ),
      backgroundColor: Colors.white,
    );
  }
}
