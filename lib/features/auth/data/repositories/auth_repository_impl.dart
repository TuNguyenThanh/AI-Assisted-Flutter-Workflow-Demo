import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:demo_ai_workflow/core/error/failures.dart';
import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/core/storage/token_storage.dart';
import 'package:demo_ai_workflow/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStorage tokenStorage,
  }) : _remote = remote,
       _tokenStorage = tokenStorage;

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokenStorage;

  @override
  Future<Result<User>> login({
    required String username,
    required String password,
  }) => _run(() async {
    final response = await _remote.login(
      username: username,
      password: password,
    );
    await _tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
    return response.user.toEntity();
  });

  @override
  Future<Result<User>> getProfile() => _run(() async {
    final user = await _remote.getMe();
    return user.toEntity();
  });

  /// Best-effort: the user is logged out in the UI even if the keychain
  /// can't be cleared; storage errors must not cross the domain boundary.
  @override
  Future<void> logout() async {
    try {
      await _tokenStorage.clear();
    } on StorageException {
      // Nothing the user can do; next login overwrites the tokens.
    }
  }

  /// Unreadable storage = no usable session → show Login, don't crash
  /// before `runApp`.
  @override
  Future<bool> hasSession() async {
    try {
      return (await _tokenStorage.readAccessToken()) != null;
    } on StorageException {
      return false;
    }
  }

  Future<Result<User>> _run(Future<User> Function() action) async {
    try {
      return Success(await action());
    } on InvalidCredentialsException {
      return const Failed(InvalidCredentialsFailure());
    } on UnauthorizedException {
      await logout();
      return const Failed(UnauthorizedFailure());
    } on NetworkException {
      return const Failed(NetworkFailure());
    } on ServerException {
      return const Failed(ServerFailure());
    } on StorageException {
      return const Failed(StorageFailure());
    }
  }
}
