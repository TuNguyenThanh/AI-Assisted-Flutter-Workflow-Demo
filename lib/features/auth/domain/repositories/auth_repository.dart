import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';

abstract interface class AuthRepository {
  Future<Result<User>> login({
    required String username,
    required String password,
  });

  Future<Result<User>> getProfile();

  Future<void> logout();

  Future<bool> hasSession();
}
