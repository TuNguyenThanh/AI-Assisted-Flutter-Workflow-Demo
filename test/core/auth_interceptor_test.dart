import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:demo_ai_workflow/core/network/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

class _Handler extends ErrorInterceptorHandler {
  Response<dynamic>? resolved;
  DioException? forwarded;
  int nextCalls = 0;
  int totalCalls = 0;

  @override
  void resolve(Response<dynamic> response) {
    totalCalls++;
    resolved = response;
  }

  @override
  void next(DioException err) {
    totalCalls++;
    nextCalls++;
    forwarded = err;
  }
}

class _RequestHandler extends RequestInterceptorHandler {
  RequestOptions? nextOptions;
  int nextCalls = 0;
  int rejectCalls = 0;

  @override
  void next(RequestOptions requestOptions) {
    nextCalls++;
    nextOptions = requestOptions;
  }

  @override
  void reject(
    DioException error, [
    bool callFollowingErrorInterceptor = false,
  ]) => rejectCalls++;
}

void main() {
  late MockTokenStorage storage;
  late MockDio refreshClient;
  late MockDio retryClient;
  late AuthInterceptor interceptor;

  setUpAll(() => registerFallbackValue(RequestOptions()));

  setUp(() {
    storage = MockTokenStorage();
    refreshClient = MockDio();
    retryClient = MockDio();
    interceptor = AuthInterceptor(
      tokenStorage: storage,
      refreshClient: refreshClient,
      retryClient: retryClient,
    );
    when(
      () => storage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => storage.readAccessToken()).thenAnswer((_) async => 'a1');
    when(() => storage.readRefreshToken()).thenAnswer((_) async => 'r1');
  });

  void stubRetry({int status = 200}) =>
      when(() => retryClient.fetch<dynamic>(any())).thenAnswer((inv) async {
        final options = inv.positionalArguments.first as RequestOptions;
        final response = Response<dynamic>(
          requestOptions: options,
          statusCode: status,
        );
        if (status >= 400) {
          throw DioException(
            requestOptions: options,
            response: response,
            type: DioExceptionType.badResponse,
          );
        }
        return response;
      });

  void stubRefresh(Future<Response<Map<String, dynamic>>> Function() answer) =>
      when(
        () => refreshClient.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer((_) => answer());

  void stubRefreshError(DioException e) => when(
    () => refreshClient.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: any<dynamic>(named: 'data'),
    ),
  ).thenThrow(e);

  DioException unauthorized(String path, {String token = 'a1'}) {
    final options = RequestOptions(
      path: path,
      headers: {'Authorization': 'Bearer $token'},
    );
    return DioException(
      requestOptions: options,
      response: Response<dynamic>(requestOptions: options, statusCode: 401),
      type: DioExceptionType.badResponse,
    );
  }

  test('refreshes token once and retries the original request', () async {
    stubRefresh(
      () async => Response(
        requestOptions: RequestOptions(),
        data: {'accessToken': 'a2', 'refreshToken': 'r2'},
      ),
    );
    stubRetry();
    final handler = _Handler();

    await interceptor.onError(unauthorized('/auth/me'), handler);

    expect(handler.resolved?.statusCode, 200);
    expect(
      handler.resolved?.requestOptions.headers['Authorization'],
      'Bearer a2',
    );
    verify(
      () => storage.saveTokens(accessToken: 'a2', refreshToken: 'r2'),
    ).called(1);
  });

  test('skips refresh when another request already refreshed', () async {
    when(() => storage.readAccessToken()).thenAnswer((_) async => 'a2');
    stubRetry();
    final handler = _Handler();

    await interceptor.onError(unauthorized('/auth/me'), handler);

    expect(handler.resolved?.statusCode, 200);
    verifyZeroInteractions(refreshClient);
  });

  test('a failing retry does not log the user out', () async {
    stubRefresh(
      () async => Response(
        requestOptions: RequestOptions(),
        data: {'accessToken': 'a2', 'refreshToken': 'r2'},
      ),
    );
    stubRetry(status: 500);
    final handler = _Handler();

    await interceptor.onError(unauthorized('/auth/me'), handler);

    expect(handler.forwarded?.response?.statusCode, 500);
    verifyNever(() => storage.clear());
  });

  test('network error during refresh keeps the session', () async {
    stubRefreshError(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );
    final handler = _Handler();

    await interceptor.onError(unauthorized('/auth/me'), handler);

    expect(handler.forwarded?.type, DioExceptionType.connectionError);
    verifyNever(() => storage.clear());
  });

  test('malformed refresh response clears the session', () async {
    stubRefresh(
      () async => Response(requestOptions: RequestOptions(), data: {}),
    );
    final handler = _Handler();

    await interceptor.onError(unauthorized('/auth/me'), handler);

    expect(handler.forwarded?.response?.statusCode, 401);
    verify(() => storage.clear()).called(1);
  });

  test('does not try to refresh on the login endpoint', () async {
    final handler = _Handler();

    await interceptor.onError(unauthorized('/auth/login'), handler);

    expect(handler.forwarded, isNotNull);
    verifyZeroInteractions(refreshClient);
  });

  test(
    'AUTH-001 AC-7: clears session when the refresh token is rejected',
    () async {
      final options = RequestOptions(path: '/auth/refresh');
      stubRefreshError(
        DioException(
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      );
      final handler = _Handler();

      await interceptor.onError(unauthorized('/auth/me'), handler);

      expect(handler.forwarded?.response?.statusCode, 401);
      verify(() => storage.clear()).called(1);
    },
  );

  group('storage errors', () {
    final errors = <String, Object>{
      'StorageException': const StorageException('boom'),
      'plain Exception': Exception('boom'),
    };

    for (final entry in errors.entries) {
      final label = entry.key;
      final error = entry.value;

      test('regression: onRequest still calls next without Authorization '
          'when readAccessToken throws $label', () async {
        when(() => storage.readAccessToken()).thenThrow(error);
        final handler = _RequestHandler();

        await interceptor.onRequest(RequestOptions(path: '/auth/me'), handler);

        expect(handler.nextCalls, 1);
        expect(handler.rejectCalls, 0);
        expect(handler.nextOptions?.headers['Authorization'], isNull);
      });

      test('regression: onError calls next once when readAccessToken '
          'throws $label', () async {
        when(() => storage.readAccessToken()).thenThrow(error);
        final handler = _Handler();

        await interceptor.onError(unauthorized('/auth/me'), handler);

        expect(handler.nextCalls, 1);
        expect(handler.totalCalls, 1);
        expect(handler.resolved, isNull);
      });

      test('regression: onError calls next once when readRefreshToken '
          'throws $label', () async {
        when(() => storage.readRefreshToken()).thenThrow(error);
        final handler = _Handler();

        await interceptor.onError(unauthorized('/auth/me'), handler);

        expect(handler.nextCalls, 1);
        expect(handler.totalCalls, 1);
        expect(handler.resolved, isNull);
      });

      test('regression: onError calls next once when clear() throws $label '
          'after a rejected refresh token', () async {
        final options = RequestOptions(path: '/auth/refresh');
        stubRefreshError(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 401,
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        when(() => storage.clear()).thenThrow(error);
        final handler = _Handler();

        await interceptor.onError(unauthorized('/auth/me'), handler);

        expect(handler.nextCalls, 1);
        expect(handler.totalCalls, 1);
        expect(handler.resolved, isNull);
      });
    }
  });
}
