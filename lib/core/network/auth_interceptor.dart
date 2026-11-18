import 'package:demo_ai_workflow/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

/// Attaches the bearer token and transparently refreshes it once on 401.
///
/// `QueuedInterceptor` serialises callbacks, so parallel 401s trigger only
/// one refresh; the others see the new token and simply retry.
///
/// Added after human review: the first AI draft had no refresh flow, so an
/// expired token kicked users straight to login (see session log issue #3).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshClient,
    required Dio retryClient,
  }) : _tokenStorage = tokenStorage,
       _refreshClient = refreshClient,
       _retryClient = retryClient;

  final TokenStorage _tokenStorage;

  /// Separate client without this interceptor to avoid infinite loops.
  final Dio _refreshClient;
  final Dio _retryClient;

  static const _retriedKey = 'auth_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    String? token;
    try {
      token = await _tokenStorage.readAccessToken();
    } on Exception {
      // Unreadable storage: send without a token; a 401 then surfaces as
      // "session expired" instead of a request that hangs forever.
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = request.extra[_retriedKey] == true;
    final isAuthEndpoint =
        request.path.startsWith('/auth/login') ||
        request.path.startsWith('/auth/refresh');

    if (!isUnauthorized || alreadyRetried || isAuthEndpoint) {
      return handler.next(err);
    }

    // `QueuedInterceptor` never awaits this method: an exception escaping
    // it would leave the request hanging and block the whole queue. Every
    // storage call below can throw, so one catch guarantees the handler
    // is always called (session log #14).
    try {
      await _refreshAndRetry(err, handler);
    } on Exception {
      handler.next(err);
    }
  }

  Future<void> _refreshAndRetry(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;

    // Another queued request may already have refreshed the token while
    // this one was waiting: just retry with the current token.
    final currentAccess = await _tokenStorage.readAccessToken();
    final sentWith = request.headers['Authorization'];
    if (currentAccess != null && sentWith != 'Bearer $currentAccess') {
      return _retry(request, currentAccess, handler, err);
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return handler.next(err);

    final String newAccess;
    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      final access = data?['accessToken'];
      final refresh = data?['refreshToken'];
      if (access is! String || refresh is! String) {
        await _tokenStorage.clear();
        return handler.next(err);
      }
      await _tokenStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );
      newAccess = access;
    } on DioException catch (refreshError) {
      // Only a rejected refresh token ends the session. A network error
      // during refresh must NOT log the user out: surface it instead so
      // the UI can offer "retry".
      final status = refreshError.response?.statusCode;
      if (status == 401 || status == 403) {
        await _tokenStorage.clear();
        return handler.next(err);
      }
      return handler.next(refreshError);
    }

    return _retry(request, newAccess, handler, err);
  }

  /// Retries [request] once. Errors of the retried call (e.g. 500, timeout)
  /// are forwarded as-is and never clear the session.
  Future<void> _retry(
    RequestOptions request,
    String accessToken,
    ErrorInterceptorHandler handler,
    DioException original,
  ) async {
    request
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..extra[_retriedKey] = true;
    try {
      return handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }
}
