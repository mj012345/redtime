import 'package:red_time_app/models/user_model.dart';

/// 로그인 결과
class SignInResult {
  final UserModel userModel;
  final bool isNewUser;

  SignInResult({required this.userModel, required this.isNewUser});
}
