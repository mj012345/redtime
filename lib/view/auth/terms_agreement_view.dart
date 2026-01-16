import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:red_time_app/constants/terms_version.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/services/auth_service.dart';
import 'package:red_time_app/models/user_model.dart';
import 'package:red_time_app/view/auth/auth_viewmodel.dart';
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
  bool _isLoading = false;

  /// 뒤로가기: 로그인 화면으로 이동
  void _handleBack() {
    Navigator.of(context).pushReplacementNamed('/login');
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: SingleChildScrollView(
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
                        const SizedBox(height: AppSpacing.xl * 2),
                        // 동의하고 시작하기 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed:
                                (_termsAgreed && _privacyAgreed && !_isLoading)
                                ? () => _handleAgreement(context)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.textDisabled,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
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
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 약관 동의 정보 저장
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('terms_agreed', true);
        await prefs.setString(
          'terms_agreed_at',
          DateTime.now().toIso8601String(),
        );
      } catch (e) {
        // SharedPreferences 저장 실패는 치명적이지 않으므로 계속 진행
      }

      // 2. Google 로그인 진행 (AuthViewModel을 통해 로그인하여 수동 로그인 플래그 설정)
      if (!context.mounted) return;
      final authViewModel = context.read<AuthViewModel>();
      final authService = AuthService();

      // AuthViewModel의 signInWithGoogle을 호출하여 수동 로그인 플래그 설정
      // signInWithGoogle() 완료를 기다림
      final loginFuture = authViewModel.signInWithGoogle();
      bool loginSuccess = false;

      try {
        // signInWithGoogle() 완료 대기 (최대 120초 - Firestore 조회 시간 고려)
        loginSuccess = await loginFuture.timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            // 타임아웃 발생 시에도 Firebase Auth에 사용자가 있으면 로그인 성공으로 간주
            final firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser != null) {
              return true;
            }
            // 타임아웃 발생했지만 사용자가 아직 없으면, authStateChanges를 기다림
            return false; // false 반환 후 아래에서 authStateChanges 확인
          },
        );
      } catch (e) {
        // 에러 발생 시에도 Firebase Auth에 사용자가 있으면 로그인 성공으로 간주
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          loginSuccess = true;
        } else {
          loginSuccess = false;
        }
      }

      // 타임아웃이나 에러로 loginSuccess가 false인 경우, authStateChanges를 기다려서 실제 로그인 확인
      if (!loginSuccess) {
        // authStateChanges 스트림을 최대 10초까지 기다림
        try {
          final userFuture = FirebaseAuth.instance
              .authStateChanges()
              .where((user) => user != null) // 사용자가 로그인될 때까지 대기
              .first;

          final timeoutFuture = Future<User?>.delayed(
            const Duration(seconds: 10),
            () {
              return null;
            },
          );

          final user = await Future.any([userFuture, timeoutFuture]);

          if (user != null) {
            loginSuccess = true;
          } else {
            loginSuccess = false;
          }
        } catch (e) {
          // 최종 확인: FirebaseAuth.instance.currentUser 체크
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            loginSuccess = true;
          } else {
            loginSuccess = false;
          }
        }
      }

      // signInWithGoogle()이 완료되었지만, authStateChanges 리스너가 userModel을 설정할 때까지 대기
      if (loginSuccess) {
        // 최대 5초까지 userModel과 isNewUser가 설정될 때까지 대기
        final maxWaitTime = const Duration(seconds: 5);
        final startTime = DateTime.now();

        while (DateTime.now().difference(startTime) < maxWaitTime) {
          await Future.delayed(const Duration(milliseconds: 200));

          final firebaseUser = FirebaseAuth.instance.currentUser;
          final viewModelUser = authViewModel.currentUser;
          final isLoading = authViewModel.isLoading;
          // FirebaseAuth에서 사용자가 확인되고, AuthViewModel의 로딩이 완료되었을 때
          if (firebaseUser != null && viewModelUser != null && !isLoading) {
            break;
          }
        }
      }
      if (!loginSuccess) {
        // 로그인 실패
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          if (authViewModel.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authViewModel.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
          // 로그인 실패 시 로그인 화면으로 돌아가기
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // 로그인 성공 - AuthViewModel에서 결과 가져오기
      // authStateChanges 리스너가 userModel과 isNewUser를 설정할 때까지 대기
      // 최대 3초까지 userModel과 isNewUser가 설정될 때까지 대기
      UserModel? userModel;
      bool? isNewUser;
      final maxWaitTime = const Duration(seconds: 3);
      final startTime = DateTime.now();

      while (userModel == null || isNewUser == null) {
        if (DateTime.now().difference(startTime) > maxWaitTime) {
          break;
        }

        userModel = authViewModel.userModel;
        isNewUser = authViewModel.isNewUser;

        if (userModel != null && isNewUser != null) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // userModel이 없으면 로그인 화면으로 복귀 (Firebase Auth 정보 필수)
      if (userModel == null) {
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인 정보를 가져오는데 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // isNewUser가 null인 경우 (Firestore 조회 실패)
      if (isNewUser == null) {
        // Firestore 조회 실패 시 기존 회원으로 가정하고 달력 화면으로 이동
        // 나중에 authStateChanges 리스너가 사용자 정보를 로드함
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pushReplacementNamed('/calendar');
        }
        return;
      }

      // 3. 신규/기존 회원 확인 및 처리
      try {
        if (isNewUser) {
          // 신규 회원: Firestore에 사용자 정보 저장 (약관 버전 정보 포함)
          final newUserModel = UserModel(
            uid: userModel.uid,
            email: userModel.email,
            displayName: null,
            photoURL: null,
            termsVersion: TermsVersion.termsVersion,
            privacyVersion: TermsVersion.privacyVersion,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await authService.saveUserToFirestore(newUserModel);
          // 로딩 해제 후 화면 전환
          if (context.mounted) {
            setState(() {
              _isLoading = false;
            });
            // 신규 회원은 회원가입 완료 화면으로 이동
            Navigator.of(context).pushReplacementNamed('/signup-complete');
          } else {}
        } else {
          // 기존 회원도 동기화 확인 (DB에 실제로 저장되어 있는지)
          final syncSuccess = await authViewModel.syncUserDataToFirestore();
          if (!syncSuccess) {
            // 사용자 데이터 동기화 실패 (계속 진행)
          } else {}

          // 기존 회원: 로딩 해제 후 화면 전환
          if (context.mounted) {
            setState(() {
              _isLoading = false;
            });
            // 기존 회원은 바로 달력 화면으로 이동
            Navigator.of(context).pushReplacementNamed('/calendar');
          } else {}
        }
      } on FirebaseException catch (e) {
        // Firestore 에러 처리
        String userMessage;

        switch (e.code) {
          case 'unavailable':
          case 'deadline-exceeded':
          case 'internal':
            userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
            break;
          case 'permission-denied':
            userMessage = '저장 권한이 없습니다.';
            break;
          default:
            userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
        }
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
          );
          // Firestore 저장 실패 시 로그인 화면으로 돌아가기
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } on PlatformException catch (e) {
        // Platform 에러 처리
        String userMessage;

        final errorMessage = e.message?.toLowerCase() ?? '';
        if (errorMessage.contains('network') ||
            errorMessage.contains('connection')) {
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
        } else {
          userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
        }
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        // 기타 예외 처리
        final errorString = e.toString().toLowerCase();
        String userMessage;

        if (errorString.contains('network') ||
            errorString.contains('connection')) {
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
        } else {
          userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
        }
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // 전체 예외 처리 (예상치 못한 오류)
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오류가 발생했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
        // 예상치 못한 오류 발생 시 로그인 화면으로 돌아가기
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
