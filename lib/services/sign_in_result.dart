import 'package:red_time_app/models/user_model.dart';

/// 로그인 결과
class SignInResult {
  final UserModel userModel;
  final bool? isNewUser; // null: 미확인 (Firestore 조회 실패), true: 신규, false: 기존

  SignInResult({required this.userModel, this.isNewUser});
}
