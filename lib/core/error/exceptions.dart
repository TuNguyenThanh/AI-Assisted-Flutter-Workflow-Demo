/// Data-layer exceptions. Mapped to `Failure` inside repositories.
sealed class AppException implements Exception {
  const AppException([this.message]);

  final String? message;

  @override
  String toString() => 'AppException: ${message ?? ''}';
}

final class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException([super.message]);
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message]);
}

final class NetworkException extends AppException {
  const NetworkException([super.message]);
}

final class ServerException extends AppException {
  const ServerException([super.message]);
}

/// Secure storage (Keychain / Keystore) could not be read or written,
/// e.g. after an Android backup restore with keys that no longer exist.
final class StorageException extends AppException {
  const StorageException([super.message]);
}
