import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/login_usecase.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._login) : super(const LoginState());

  final LoginUseCase _login;

  static const minPasswordLength = 6;

  Future<void> submit({
    required String username,
    required String password,
  }) async {
    // Guard against double-tap: AC-5 in docs/specs/AUTH-001-spec.md.
    if (state.isSubmitting) return;

    final validationError = _validate(username, password);
    if (validationError != null) {
      emit(
        LoginState(status: LoginStatus.failure, errorMessage: validationError),
      );
      return;
    }

    emit(const LoginState(status: LoginStatus.submitting));
    final result = await _login(username: username, password: password);

    // The page may be popped while the request is in flight.
    if (isClosed) return;

    switch (result) {
      case Success(:final value):
        emit(LoginState(status: LoginStatus.success, user: value));
      case Failed(:final failure):
        emit(
          LoginState(
            status: LoginStatus.failure,
            errorMessage: failure.message,
          ),
        );
    }
  }

  String? _validate(String username, String password) {
    if (username.trim().isEmpty) return 'Please enter your username.';
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    return null;
  }
}
