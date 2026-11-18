part of 'login_cubit.dart';

enum LoginStatus { initial, submitting, success, failure }

final class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.initial,
    this.user,
    this.errorMessage,
  });

  final LoginStatus status;
  final User? user;
  final String? errorMessage;

  bool get isSubmitting => status == LoginStatus.submitting;

  @override
  List<Object?> get props => [status, user, errorMessage];
}
