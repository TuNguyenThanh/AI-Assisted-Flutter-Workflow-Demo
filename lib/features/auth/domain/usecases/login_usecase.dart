import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<User>> call({
    required String username,
    required String password,
  }) => _repository.login(username: username.trim(), password: password);
}
