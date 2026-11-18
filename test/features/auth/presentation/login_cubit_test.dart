import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:demo_ai_workflow/core/error/failures.dart';
import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/login_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockLoginUseCase login;

  setUp(() => login = MockLoginUseCase());

  void stubLogin(Result<User> result) => when(
    () => login(
      username: any(named: 'username'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  group('LoginCubit', () {
    blocTest<LoginCubit, LoginState>(
      'AUTH-001 AC-1: emits [submitting, success] on valid credentials',
      setUp: () => stubLogin(const Success(tUser)),
      build: () => LoginCubit(login),
      act: (c) => c.submit(username: 'emilys', password: 'emilyspass'),
      expect: () => const [
        LoginState(status: LoginStatus.submitting),
        LoginState(status: LoginStatus.success, user: tUser),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'AUTH-001 AC-2: emits failure message on wrong password',
      setUp: () => stubLogin(const Failed(InvalidCredentialsFailure())),
      build: () => LoginCubit(login),
      act: (c) => c.submit(username: 'emilys', password: 'wrongpass'),
      expect: () => [
        const LoginState(status: LoginStatus.submitting),
        LoginState(
          status: LoginStatus.failure,
          errorMessage: const InvalidCredentialsFailure().message,
        ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'AUTH-001 AC-4: validates empty username without calling API',
      build: () => LoginCubit(login),
      act: (c) => c.submit(username: '   ', password: 'emilyspass'),
      expect: () => const [
        LoginState(
          status: LoginStatus.failure,
          errorMessage: 'Please enter your username.',
        ),
      ],
      verify: (_) => verifyNever(
        () => login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ),
    );

    blocTest<LoginCubit, LoginState>(
      'AUTH-001 AC-4: validates short password',
      build: () => LoginCubit(login),
      act: (c) => c.submit(username: 'emilys', password: '123'),
      expect: () => [
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.failure)
            .having((s) => s.errorMessage, 'msg', contains('at least 6')),
      ],
    );

    test(
      'AUTH-001 AC-5: ignores a second submit while the first is in flight',
      () async {
        final completer = Completer<Result<User>>();
        when(
          () => login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => completer.future);
        final cubit = LoginCubit(login);

        unawaited(cubit.submit(username: 'emilys', password: 'emilyspass'));
        unawaited(cubit.submit(username: 'emilys', password: 'emilyspass'));
        completer.complete(const Success(tUser));
        await Future<void>.delayed(Duration.zero);

        verify(
          () => login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).called(1);
        await cubit.close();
      },
    );

    test('does not emit after close (regression for session-log #4)', () async {
      final completer = Completer<Result<User>>();
      when(
        () => login(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => completer.future);
      final cubit = LoginCubit(login);

      final pending = cubit.submit(username: 'emilys', password: 'emilyspass');
      await cubit.close();
      completer.complete(const Success(tUser));

      await expectLater(pending, completes);
    });
  });
}
