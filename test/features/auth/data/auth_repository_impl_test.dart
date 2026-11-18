import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:demo_ai_workflow/core/error/failures.dart';
import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/data/models/user_model.dart';
import 'package:demo_ai_workflow/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRemoteDataSource remote;
  late MockTokenStorage storage;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = MockAuthRemoteDataSource();
    storage = MockTokenStorage();
    repository = AuthRepositoryImpl(remote: remote, tokenStorage: storage);
    when(() => storage.clear()).thenAnswer((_) async {});
    when(
      () => storage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
  });

  group('login', () {
    test('AUTH-001 AC-1: saves tokens and returns user on success', () async {
      when(
        () => remote.login(username: 'emilys', password: 'emilyspass'),
      ).thenAnswer((_) async => LoginResponseModel.fromJson(tLoginJson));

      final result = await repository.login(
        username: 'emilys',
        password: 'emilyspass',
      );

      expect(result, isA<Success<dynamic>>());
      expect((result as Success).value, tUser);
      verify(
        () => storage.saveTokens(
          accessToken: 'access-123',
          refreshToken: 'refresh-456',
        ),
      ).called(1);
    });

    test(
      'AUTH-001 AC-2: maps invalid credentials and stores nothing',
      () async {
        when(
          () => remote.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const InvalidCredentialsException());

        final result = await repository.login(username: 'a', password: 'b');

        expect((result as Failed).failure, const InvalidCredentialsFailure());
        verifyNever(
          () => storage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        );
      },
    );

    test('AUTH-001 AC-3: maps network errors', () async {
      when(
        () => remote.login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const NetworkException());

      final result = await repository.login(username: 'a', password: 'b');

      expect((result as Failed).failure, const NetworkFailure());
    });
  });

  group('storage errors', () {
    test(
      'regression: login returns StorageFailure when saveTokens throws',
      () async {
        when(
          () => remote.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => LoginResponseModel.fromJson(tLoginJson));
        when(
          () => storage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenThrow(const StorageException('boom'));

        final result = await repository.login(username: 'a', password: 'b');

        expect(result, isA<Failed<dynamic>>());
        expect((result as Failed).failure, const StorageFailure());
      },
    );

    test('regression: logout completes normally when clear throws', () async {
      when(() => storage.clear()).thenThrow(const StorageException('boom'));

      await expectLater(repository.logout(), completes);
    });

    test('regression: getProfile returns UnauthorizedFailure when clear '
        'throws after an unauthorized response', () async {
      when(() => remote.getMe()).thenThrow(const UnauthorizedException());
      when(() => storage.clear()).thenThrow(const StorageException('boom'));

      final result = await repository.getProfile();

      expect(result, isA<Failed<dynamic>>());
      expect((result as Failed).failure, const UnauthorizedFailure());
    });

    test('regression: hasSession returns false when read throws', () async {
      when(
        () => storage.readAccessToken(),
      ).thenThrow(const StorageException('boom'));

      expect(await repository.hasSession(), isFalse);
    });
  });

  group('getProfile', () {
    test('returns user', () async {
      when(
        () => remote.getMe(),
      ).thenAnswer((_) async => UserModel.fromJson(tLoginJson));

      final result = await repository.getProfile();

      expect((result as Success).value, tUser);
    });

    test('AUTH-001 AC-7: clears session when unauthorized', () async {
      when(() => remote.getMe()).thenThrow(const UnauthorizedException());

      final result = await repository.getProfile();

      expect((result as Failed).failure, const UnauthorizedFailure());
      verify(() => storage.clear()).called(1);
    });

    test('maps server errors', () async {
      when(() => remote.getMe()).thenThrow(const ServerException('500'));

      final result = await repository.getProfile();

      expect((result as Failed).failure, isA<ServerFailure>());
    });
  });

  group('session', () {
    test('hasSession reflects stored token', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => 'tok');
      expect(await repository.hasSession(), isTrue);

      when(() => storage.readAccessToken()).thenAnswer((_) async => null);
      expect(await repository.hasSession(), isFalse);
    });

    test('AUTH-001 AC-6: logout clears tokens', () async {
      await repository.logout();
      verify(() => storage.clear()).called(1);
    });
  });
}
