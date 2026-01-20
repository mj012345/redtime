import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';
import 'package:red_time_app/widgets/common_dialog.dart';

class MyView extends StatefulWidget {
  const MyView({super.key});

  @override
  State<MyView> createState() => _MyViewState();
}

class _MyViewState extends State<MyView> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: '로그아웃',
        content: '정말 로그아웃 하시겠습니까?',
        confirmLabel: '로그아웃',
        confirmColor: Colors.red,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (shouldSignOut == true && context.mounted) {
      await authViewModel.signOut();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: '계정 삭제',
        content: '정말 계정을 삭제하시겠습니까?\n삭제된 계정은 복구할 수 없습니다.',
        confirmLabel: '삭제',
        confirmColor: Colors.red,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (shouldDelete == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            const Center(child: CircularProgressIndicator()),
      );

      try {
        final success = await authViewModel.deleteAccount();

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (success) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/', (route) => false);
          }
        } else {
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
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MY'),
        backgroundColor: AppColors.background,
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
                  final email = userModel?.email ?? '';

                  return IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 1. 사용자 정보 카드
                        _buildSectionCard(
                          title: '내정보',
                          children: [
                            Text(
                              email,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _handleDeleteAccount(context),
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
                        const SizedBox(height: AppSpacing.md),
                        // 2. 앱 정보 카드
                        _buildSectionCard(
                          title: '앱 정보',
                          children: [
                            _buildInfoRow(
                              label: '앱 버전 $_appVersion',
                              trailing: Text(
                                '최신 버전',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textDisabled,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // 로그아웃 버튼
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
      backgroundColor: AppColors.background,
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.title.copyWith(
              fontSize: 16,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
