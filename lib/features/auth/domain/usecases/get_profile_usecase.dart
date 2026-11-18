import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/domain/repositories/auth_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<User>> call() => _repository.getProfile();
}
