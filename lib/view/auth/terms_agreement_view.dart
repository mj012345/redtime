import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red_time_app/constants/terms_version.dart';
import 'package:red_time_app/theme/app_colors.dart';
import 'package:red_time_app/theme/app_spacing.dart';
import 'package:red_time_app/theme/app_text_styles.dart';
import 'package:red_time_app/services/auth_service.dart';
import 'package:red_time_app/services/sign_in_result.dart';
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
        debugPrint('SharedPreferences 저장 실패: $e');
        // SharedPreferences 저장 실패는 치명적이지 않으므로 계속 진행
      }

      // 2. Google 로그인 진행
      final authService = AuthService();
      SignInResult? signInResult;
      try {
        signInResult = await authService.signInWithGoogle();
      } on FirebaseException catch (e) {
        // Firebase Auth 에러 처리
        String userMessage;
        String debugMessage;

        switch (e.code) {
          case 'network-request-failed':
            userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
            debugMessage = '❌ Firebase Auth 네트워크 오류 [${e.code}]: ${e.message}';
            break;
          case 'user-disabled':
            userMessage = '사용할 수 없는 계정입니다.';
            debugMessage = '❌ Firebase Auth 계정 비활성화 [${e.code}]: ${e.message}';
            break;
          case 'invalid-credential':
            userMessage = '인증 정보가 올바르지 않습니다.';
            debugMessage =
                '❌ Firebase Auth 잘못된 인증 정보 [${e.code}]: ${e.message}';
            break;
          case 'operation-not-allowed':
            userMessage = 'Google 로그인이 허용되지 않았습니다.';
            debugMessage = '❌ Firebase Auth 운영 미허용 [${e.code}]: ${e.message}';
            break;
          default:
            userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
            debugMessage =
                '❌ Firebase Auth 알 수 없는 에러 [${e.code}]: ${e.message}';
        }

        debugPrint('=== Firebase Auth 에러 ===');
        debugPrint(debugMessage);
        debugPrint('에러 코드: ${e.code}');
        debugPrint('에러 메시지: ${e.message}');
        debugPrint('===================');

        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
          );
        }
        return;
      } on PlatformException catch (e) {
        // Platform 에러 처리
        String userMessage;
        String debugMessage;

        if (e.code == 'sign_in_failed') {
          if (e.message?.contains('ApiException: 10') == true) {
            userMessage =
                'Google 로그인 설정 오류가 발생했습니다.\nFirebase Console에서 SHA-1 지문을 확인해주세요.';
            debugMessage =
                '❌ Google Sign-In 설정 오류 [${e.code}]: ApiException: 10 - ${e.message}';
          } else if (e.message?.toLowerCase().contains('network') == true ||
              e.message?.toLowerCase().contains('connection') == true) {
            userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
            debugMessage = '❌ Google Sign-In 네트워크 오류 [${e.code}]: ${e.message}';
          } else {
            userMessage = 'Google 로그인에 실패했습니다.';
            debugMessage = '❌ Google Sign-In 실패 [${e.code}]: ${e.message}';
          }
        } else {
          userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
          debugMessage = '❌ Platform 알 수 없는 에러 [${e.code}]: ${e.message}';
        }

        debugPrint('=== Platform 에러 ===');
        debugPrint(debugMessage);
        debugPrint('에러 코드: ${e.code}');
        debugPrint('에러 메시지: ${e.message}');
        debugPrint('===================');

        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
          );
        }
        return;
      } catch (e) {
        // 기타 예외 처리
        final errorString = e.toString().toLowerCase();
        String? userMessage;
        String debugMessage;

        if (errorString.contains('canceled') ||
            errorString.contains('cancelled')) {
          // 사용자 취소는 에러 메시지 표시하지 않음
          userMessage = null;
          debugMessage = '✅ 사용자 로그인 취소: $e';
        } else if (errorString.contains('network') ||
            errorString.contains('connection')) {
          userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
          debugMessage = '❌ 네트워크 오류 [${e.runtimeType}]: $e';
        } else {
          userMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
          debugMessage = '❌ 알 수 없는 에러 [${e.runtimeType}]: $e';
        }

        debugPrint('=== 기타 에러 ===');
        debugPrint(debugMessage);
        debugPrint('에러 타입: ${e.runtimeType}');
        debugPrint('에러 메시지: $e');
        debugPrint('===================');

        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          if (userMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
            );
          }
        }
        return;
      }

      if (signInResult == null) {
        // 사용자가 로그인 취소
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // 3. 신규/기존 회원 확인 및 처리
      if (signInResult.isNewUser) {
        // 신규 회원: Firestore에 사용자 정보 저장 (약관 버전 정보 포함)
        try {
          final newUserModel = UserModel(
            uid: signInResult.userModel.uid,
            email: signInResult.userModel.email,
            displayName: null,
            photoURL: null,
            termsVersion: TermsVersion.termsVersion,
            privacyVersion: TermsVersion.privacyVersion,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await authService.saveUserToFirestore(newUserModel);

          // 성공 시 회원가입 완료 화면으로 이동
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/signup-complete');
          }
        } on FirebaseException catch (e) {
          // Firestore 에러 처리
          String userMessage;
          String debugMessage;

          switch (e.code) {
            case 'unavailable':
            case 'deadline-exceeded':
            case 'internal':
              userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
              debugMessage = '❌ Firestore 네트워크 오류 [${e.code}]: ${e.message}';
              break;
            case 'permission-denied':
              userMessage = '저장 권한이 없습니다.';
              debugMessage = '❌ Firestore 권한 거부 [${e.code}]: ${e.message}';
              break;
            default:
              userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
              debugMessage = '❌ Firestore 저장 실패 [${e.code}]: ${e.message}';
          }

          debugPrint('=== Firestore 저장 에러 ===');
          debugPrint(debugMessage);
          debugPrint('에러 코드: ${e.code}');
          debugPrint('에러 메시지: ${e.message}');
          debugPrint('===================');

          if (context.mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
            );
          }
        } on PlatformException catch (e) {
          // Platform 에러 처리
          String userMessage;
          String debugMessage;

          final errorMessage = e.message?.toLowerCase() ?? '';
          if (errorMessage.contains('network') ||
              errorMessage.contains('connection')) {
            userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
            debugMessage = '❌ Platform 네트워크 오류 [${e.code}]: ${e.message}';
          } else {
            userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
            debugMessage = '❌ Platform 에러 [${e.code}]: ${e.message}';
          }

          debugPrint('=== Platform 에러 ===');
          debugPrint(debugMessage);
          debugPrint('에러 코드: ${e.code}');
          debugPrint('에러 메시지: ${e.message}');
          debugPrint('===================');

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
          String debugMessage;

          if (errorString.contains('network') ||
              errorString.contains('connection')) {
            userMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
            debugMessage = '❌ 네트워크 오류 [${e.runtimeType}]: $e';
          } else {
            userMessage = '회원가입에 실패했습니다. 다시 시도해주세요.';
            debugMessage = '❌ 알 수 없는 에러 [${e.runtimeType}]: $e';
          }

          debugPrint('=== 기타 에러 ===');
          debugPrint(debugMessage);
          debugPrint('에러 타입: ${e.runtimeType}');
          debugPrint('에러 메시지: $e');
          debugPrint('===================');

          if (context.mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(userMessage), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        // 기존 회원: 바로 달력 화면으로 이동
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/calendar');
        }
      }
    } catch (e) {
      // 전체 예외 처리 (예상치 못한 오류)
      debugPrint('약관 동의 처리 실패: $e');
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
      }
    }
  }
}
