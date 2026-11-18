import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over token persistence so it can be mocked in tests.
abstract interface class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

/// Tokens live in Keychain / EncryptedSharedPreferences, never in plain
/// SharedPreferences (see docs/session-logs/AUTH-001.md, issue #1).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  @override
  Future<String?> readAccessToken() =>
      _guard(() => _storage.read(key: _accessKey));

  @override
  Future<String?> readRefreshToken() =>
      _guard(() => _storage.read(key: _refreshKey));

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) => _guard(() async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  });

  @override
  Future<void> clear() => _guard(() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  });

  /// Keychain / Keystore failures surface as [PlatformException]; callers
  /// only ever see the data-layer [StorageException] (session log #14).
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (e) {
      throw StorageException(e.code);
    }
  }
}
