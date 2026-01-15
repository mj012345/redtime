import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    debugPrint('🚀 [약관 동의] 약관 동의 처리 시작');
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 약관 동의 정보 저장
      debugPrint('📝 [약관 동의] Step 1: 약관 동의 정보 저장 시작');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('terms_agreed', true);
        await prefs.setString(
          'terms_agreed_at',
          DateTime.now().toIso8601String(),
        );
        debugPrint('✅ [약관 동의] Step 1: 약관 동의 정보 저장 완료');
      } catch (e) {
        debugPrint('⚠️ [약관 동의] Step 1: SharedPreferences 저장 실패: $e');
        // SharedPreferences 저장 실패는 치명적이지 않으므로 계속 진행
      }

      // 2. Google 로그인 진행 (AuthViewModel을 통해 로그인하여 수동 로그인 플래그 설정)
      debugPrint('🔐 [약관 동의] Step 2: Google 로그인 시작');
      final authViewModel = context.read<AuthViewModel>();
      final authService = AuthService();

      // AuthViewModel의 signInWithGoogle을 호출하여 수동 로그인 플래그 설정
      debugPrint('🔐 [약관 동의] Step 2-1: authViewModel.signInWithGoogle() 호출');

      // signInWithGoogle() 완료를 기다림
      final loginFuture = authViewModel.signInWithGoogle();
      bool loginSuccess = false;

      try {
        // signInWithGoogle() 완료 대기 (최대 120초 - Firestore 조회 시간 고려)
        loginSuccess = await loginFuture.timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            debugPrint('⏰ [약관 동의] Step 2-1: signInWithGoogle() 타임아웃 (120초)');
            // 타임아웃 발생 시에도 Firebase Auth에 사용자가 있으면 로그인 성공으로 간주
            final firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser != null) {
              debugPrint(
                '⚠️ [약관 동의] Step 2-1: 타임아웃 발생했지만 Firebase Auth에 사용자 존재 - 로그인 성공으로 처리',
              );
              return true;
            }
            // 타임아웃 발생했지만 사용자가 아직 없으면, authStateChanges를 기다림
            debugPrint('⏳ [약관 동의] Step 2-1: 타임아웃 후 authStateChanges 대기 시작');
            return false; // false 반환 후 아래에서 authStateChanges 확인
          },
        );
        debugPrint('🔐 [약관 동의] Step 2-2: signInWithGoogle() 완료: $loginSuccess');
      } catch (e) {
        debugPrint('❌ [약관 동의] Step 2-1: signInWithGoogle() 에러: $e');
        // 에러 발생 시에도 Firebase Auth에 사용자가 있으면 로그인 성공으로 간주
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          debugPrint(
            '⚠️ [약관 동의] Step 2-1: 에러 발생했지만 Firebase Auth에 사용자 존재 - 로그인 성공으로 처리',
          );
          loginSuccess = true;
        } else {
          loginSuccess = false;
        }
      }

      // 타임아웃이나 에러로 loginSuccess가 false인 경우, authStateChanges를 기다려서 실제 로그인 확인
      if (!loginSuccess) {
        debugPrint('⏳ [약관 동의] Step 2-1-1: authStateChanges로 실제 로그인 상태 확인 시작');
        // authStateChanges 스트림을 최대 10초까지 기다림
        try {
          final userFuture = FirebaseAuth.instance
              .authStateChanges()
              .where((user) => user != null) // 사용자가 로그인될 때까지 대기
              .first;

          final timeoutFuture = Future<User?>.delayed(
            const Duration(seconds: 10),
            () {
              debugPrint('⏰ [약관 동의] Step 2-1-1: authStateChanges 타임아웃 (10초)');
              return null;
            },
          );

          final user = await Future.any([userFuture, timeoutFuture]);

          if (user != null) {
            debugPrint(
              '✅ [약관 동의] Step 2-1-1: authStateChanges로 로그인 확인됨: ${user.uid}',
            );
            loginSuccess = true;
          } else {
            debugPrint('❌ [약관 동의] Step 2-1-1: authStateChanges에서 사용자 없음');
            loginSuccess = false;
          }
        } catch (e) {
          debugPrint('❌ [약관 동의] Step 2-1-1: authStateChanges 확인 실패: $e');
          // 최종 확인: FirebaseAuth.instance.currentUser 체크
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            debugPrint(
              '✅ [약관 동의] Step 2-1-1: 최종 확인 - Firebase Auth에 사용자 존재: ${firebaseUser.uid}',
            );
            loginSuccess = true;
          } else {
            loginSuccess = false;
          }
        }
      }

      // signInWithGoogle()이 완료되었지만, authStateChanges 리스너가 userModel을 설정할 때까지 대기
      if (loginSuccess) {
        debugPrint('⏳ [약관 동의] Step 2-3: authStateChanges 리스너 완료 대기 중...');

        // 최대 5초까지 userModel과 isNewUser가 설정될 때까지 대기
        final maxWaitTime = const Duration(seconds: 5);
        final startTime = DateTime.now();

        while (DateTime.now().difference(startTime) < maxWaitTime) {
          await Future.delayed(const Duration(milliseconds: 200));

          final firebaseUser = FirebaseAuth.instance.currentUser;
          final viewModelUser = authViewModel.currentUser;
          final isLoading = authViewModel.isLoading;

          debugPrint('🔍 [약관 동의] Step 2-3: 상태 확인 중...');
          debugPrint(
            '  - FirebaseAuth.instance.currentUser: ${firebaseUser?.uid}',
          );
          debugPrint('  - authViewModel.currentUser: ${viewModelUser?.uid}');
          debugPrint('  - authViewModel.isLoading: $isLoading');

          // FirebaseAuth에서 사용자가 확인되고, AuthViewModel의 로딩이 완료되었을 때
          if (firebaseUser != null && viewModelUser != null && !isLoading) {
            debugPrint('✅ [약관 동의] Step 2-3: 로그인 완료 확인');
            break;
          }
        }
      }

      debugPrint('🔐 [약관 동의] Step 2-3: 최종 로그인 결과: $loginSuccess');
      debugPrint(
        '🔐 [약관 동의] Step 2-4: authViewModel.isLoading: ${authViewModel.isLoading}',
      );
      debugPrint(
        '🔐 [약관 동의] Step 2-5: authViewModel.errorMessage: ${authViewModel.errorMessage}',
      );

      if (!loginSuccess) {
        // 로그인 실패
        debugPrint('❌ [약관 동의] Step 2: 로그인 실패 - 로그인 화면으로 복귀 필요');
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          debugPrint('❌ [약관 동의] Step 2: 로딩 해제 완료');
          if (authViewModel.errorMessage != null) {
            debugPrint(
              '❌ [약관 동의] Step 2: 에러 메시지 표시: ${authViewModel.errorMessage}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authViewModel.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
          // 로그인 실패 시 로그인 화면으로 돌아가기
          debugPrint('❌ [약관 동의] Step 2: 로그인 화면으로 돌아가기 시도');
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // 로그인 성공 - AuthViewModel에서 결과 가져오기
      debugPrint('✅ [약관 동의] Step 3: 로그인 성공 - 사용자 정보 확인 시작');
      // authStateChanges 리스너가 userModel과 isNewUser를 설정할 때까지 대기
      debugPrint('⏳ [약관 동의] Step 3-1: userModel과 isNewUser 설정 대기 중...');

      // 최대 3초까지 userModel과 isNewUser가 설정될 때까지 대기
      UserModel? userModel;
      bool? isNewUser;
      final maxWaitTime = const Duration(seconds: 3);
      final startTime = DateTime.now();

      while (userModel == null || isNewUser == null) {
        if (DateTime.now().difference(startTime) > maxWaitTime) {
          debugPrint('⏰ [약관 동의] Step 3: 사용자 정보 대기 타임아웃');
          break;
        }

        userModel = authViewModel.userModel;
        isNewUser = authViewModel.isNewUser;

        if (userModel != null && isNewUser != null) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      final currentUser = authViewModel.currentUser;

      debugPrint('✅ [약관 동의] Step 3-2: 사용자 정보 확인');
      debugPrint('  - currentUser: ${currentUser?.uid}');
      debugPrint(
        '  - userModel: ${userModel != null} (uid: ${userModel?.uid})',
      );
      debugPrint('  - isNewUser: $isNewUser');

      // userModel이 없으면 로그인 화면으로 복귀 (Firebase Auth 정보 필수)
      if (userModel == null) {
        debugPrint('❌ [약관 동의] Step 3: userModel 없음 - 로그인 화면으로 복귀');
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
        debugPrint(
          '⚠️ [약관 동의] Step 3: Firestore 조회 실패 - 기존 회원으로 가정하고 달력 화면으로 이동',
        );
        // Firestore 조회 실패 시 기존 회원으로 가정하고 달력 화면으로 이동
        // 나중에 authStateChanges 리스너가 사용자 정보를 로드함
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          debugPrint('🚀 [약관 동의] Step 3: 달력 화면으로 이동 (Firestore 조회 실패)');
          Navigator.of(context).pushReplacementNamed('/calendar');
        }
        return;
      }

      // 3. 신규/기존 회원 확인 및 처리
      debugPrint('📋 [약관 동의] Step 4: 신규/기존 회원 확인 및 처리 시작');
      try {
        if (isNewUser) {
          debugPrint('✨ [약관 동의] Step 4: 신규 회원 감지');
          debugPrint('💾 [약관 동의] Step 4-1: Firestore에 사용자 정보 저장 시작');
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
          debugPrint('✅ [약관 동의] Step 4-2: Firestore 저장 완료');

          // 로딩 해제 후 화면 전환
          if (context.mounted) {
            debugPrint('🔄 [약관 동의] Step 4-3: 로딩 해제 및 화면 전환 시작');
            setState(() {
              _isLoading = false;
            });
            debugPrint('✅ [약관 동의] Step 4-4: 로딩 해제 완료');
            debugPrint('🚀 [약관 동의] Step 4-5: 회원가입 완료 화면으로 이동 시도');
            // 신규 회원은 회원가입 완료 화면으로 이동
            Navigator.of(context).pushReplacementNamed('/signup-complete');
            debugPrint(
              '✅ [약관 동의] Step 4-6: Navigator.pushReplacementNamed 호출 완료',
            );
          } else {
            debugPrint(
              '⚠️ [약관 동의] Step 4: context.mounted == false (위젯이 이미 dispose됨)',
            );
          }
        } else {
          debugPrint('👤 [약관 동의] Step 4: 기존 회원 감지');

          // 기존 회원도 동기화 확인 (DB에 실제로 저장되어 있는지)
          debugPrint('🔄 [약관 동의] Step 4-1: 사용자 데이터 동기화 확인 시작');
          final syncSuccess = await authViewModel.syncUserDataToFirestore();
          if (!syncSuccess) {
            debugPrint('⚠️ [약관 동의] Step 4-1: 사용자 데이터 동기화 실패 (계속 진행)');
          } else {
            debugPrint('✅ [약관 동의] Step 4-1: 사용자 데이터 동기화 완료');
          }

          // 기존 회원: 로딩 해제 후 화면 전환
          if (context.mounted) {
            debugPrint('🔄 [약관 동의] Step 4-2: 로딩 해제 및 화면 전환 시작');
            setState(() {
              _isLoading = false;
            });
            debugPrint('✅ [약관 동의] Step 4-3: 로딩 해제 완료');
            debugPrint('🚀 [약관 동의] Step 4-4: 달력 화면으로 이동 시도');
            // 기존 회원은 바로 달력 화면으로 이동
            Navigator.of(context).pushReplacementNamed('/calendar');
            debugPrint(
              '✅ [약관 동의] Step 4-5: Navigator.pushReplacementNamed 호출 완료',
            );
          } else {
            debugPrint(
              '⚠️ [약관 동의] Step 4: context.mounted == false (위젯이 이미 dispose됨)',
            );
          }
        }
      } on FirebaseException catch (e) {
        // Firestore 에러 처리
        debugPrint('❌ [약관 동의] Step 4: Firestore 예외 발생');
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
          // Firestore 저장 실패 시 로그인 화면으로 돌아가기
          debugPrint('❌ [약관 동의] Firestore 저장 실패 - 로그인 화면으로 복귀');
          Navigator.of(context).pushReplacementNamed('/login');
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
    } catch (e, stackTrace) {
      // 전체 예외 처리 (예상치 못한 오류)
      debugPrint('❌❌❌ [약관 동의] 예상치 못한 예외 발생 ❌❌❌');
      debugPrint('예외 타입: ${e.runtimeType}');
      debugPrint('예외 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      debugPrint('==========================================');

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
        debugPrint('❌ [약관 동의] 예상치 못한 오류 - 로그인 화면으로 복귀');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }

    debugPrint('🏁 [약관 동의] 약관 동의 처리 완료');
  }
}
