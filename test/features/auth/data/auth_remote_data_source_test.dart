import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:demo_ai_workflow/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockDio dio;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = AuthRemoteDataSourceImpl(dio);
  });

  DioException dioError(DioExceptionType type, {int? status}) {
    final options = RequestOptions();
    return DioException(
      requestOptions: options,
      type: type,
      response: status == null
          ? null
          : Response<dynamic>(requestOptions: options, statusCode: status),
    );
  }

  void stubLogin(Future<Response<Map<String, dynamic>>> Function() answer) =>
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: any<dynamic>(named: 'data'),
        ),
      ).thenAnswer((_) => answer());

  void stubLoginError(DioException e) => when(
    () => dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: any<dynamic>(named: 'data'),
    ),
  ).thenThrow(e);

  group('login', () {
    test('sends credentials and parses response', () async {
      stubLogin(
        () async =>
            Response(requestOptions: RequestOptions(), data: tLoginJson),
      );

      final result = await dataSource.login(
        username: 'emilys',
        password: 'emilyspass',
      );

      expect(result.accessToken, 'access-123');
      final body =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/auth/login',
                  data: captureAny<dynamic>(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(body['username'], 'emilys');
      expect(body['password'], 'emilyspass');
    });

    test('AUTH-001 AC-2: 400 maps to InvalidCredentialsException', () {
      stubLoginError(dioError(DioExceptionType.badResponse, status: 400));

      expect(
        () => dataSource.login(username: 'a', password: 'b'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test(
      'AUTH-001 AC-3: connection errors and timeouts map to NetworkException',
      () {
        for (final type in [
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
        ]) {
          stubLoginError(dioError(type));
          expect(
            () => dataSource.login(username: 'a', password: 'b'),
            throwsA(isA<NetworkException>()),
            reason: '$type',
          );
        }
      },
    );

    test('malformed body maps to ServerException', () {
      stubLogin(
        () async => Response(
          requestOptions: RequestOptions(),
          data: const {'id': 'not-an-int'},
        ),
      );

      expect(
        () => dataSource.login(username: 'a', password: 'b'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('getMe', () {
    test('parses user', () async {
      when(() => dio.get<Map<String, dynamic>>('/auth/me')).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(), data: tLoginJson),
      );

      final user = await dataSource.getMe();

      expect(user.toEntity(), tUser);
    });

    test('AUTH-001 AC-7: 401 maps to UnauthorizedException', () {
      when(
        () => dio.get<Map<String, dynamic>>('/auth/me'),
      ).thenThrow(dioError(DioExceptionType.badResponse, status: 401));

      expect(dataSource.getMe, throwsA(isA<UnauthorizedException>()));
    });

    test('5xx maps to ServerException', () {
      when(
        () => dio.get<Map<String, dynamic>>('/auth/me'),
      ).thenThrow(dioError(DioExceptionType.badResponse, status: 503));

      expect(dataSource.getMe, throwsA(isA<ServerException>()));
    });
  });
}
