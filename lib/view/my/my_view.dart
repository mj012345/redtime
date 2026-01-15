import 'package:flutter/foundation.dart';
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

    // 로그아웃 확인 다이얼로그 표시
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
      debugPrint('🚪 [MyView] 로그아웃 시작');
      await authViewModel.signOut();

      // 로그아웃 완료 후 잠시 대기하여 완전히 로그아웃되었는지 확인
      await Future.delayed(const Duration(milliseconds: 500));

      // 로그아웃 완료 후 로그인 페이지로 이동
      if (context.mounted) {
        debugPrint('🚪 [MyView] 로그인 페이지로 이동');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    // 계정 삭제 확인 다이얼로그 표시
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        content: const Text('정말 계정을 삭제하시겠습니까?\n삭제된 계정은 복구할 수 없습니다.'),
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
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            const Center(child: CircularProgressIndicator()),
      );

      try {
        final success = await authViewModel.deleteAccount();

        // 로딩 다이얼로그 닫기 (context.mounted 확인)
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (success) {
          // 계정 삭제 성공 - 로그인 페이지로 이동
          // context.mounted 확인 후 화면 이동
          if (context.mounted) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        } else {
          // 계정 삭제 실패 - 에러 메시지 표시
          // context.mounted 확인 후 메시지 표시
          if (context.mounted) {
            final errorMessage = authViewModel.errorMessage ?? '계정 삭제에 실패했습니다.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        // 예외 발생 시에도 로딩 다이얼로그 닫기
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();

          // 에러 메시지 표시
          final errorMessage =
              authViewModel.errorMessage ?? '계정 삭제 중 오류가 발생했습니다.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        debugPrint('❌ [MyView] 계정 삭제 중 예외 발생: $e');
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
      body: LayoutBuilder(
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
                              const SizedBox(height: AppSpacing.sm),
                              // 계정 삭제 버튼
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _handleDeleteAccount(context),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    '계정 삭제',
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.red,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                  ),
                                ),
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
