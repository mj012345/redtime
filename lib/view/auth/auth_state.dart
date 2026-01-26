import 'package:firebase_auth/firebase_auth.dart';
import 'package:red_time_app/models/user_model.dart';

sealed class AuthState {
  const AuthState();
}

class AuthUninitialized extends AuthState {
  const AuthUninitialized();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticated extends AuthState {
  final User user;
  final UserModel userModel;
  final bool isNewUser;
  final bool showCompletionScreen;

  const Authenticated(
    this.user,
    this.userModel, {
    this.isNewUser = false,
    this.showCompletionScreen = false,
  });
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
