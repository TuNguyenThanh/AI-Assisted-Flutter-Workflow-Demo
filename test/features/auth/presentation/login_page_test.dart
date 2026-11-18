import 'package:bloc_test/bloc_test.dart';
import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/login_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/login_page.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

void main() {
  late MockLoginCubit cubit;

  setUp(() {
    cubit = MockLoginCubit();
    when(
      () => cubit.submit(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget wrap({ThemeData? theme, double textScale = 1}) => MaterialApp(
    theme: theme ?? AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: BlocProvider<LoginCubit>.value(
      value: cubit,
      child: const LoginPage(),
    ),
    routes: {
      ProfilePage.routeName: (_) => const Scaffold(body: Text('PROFILE')),
    },
  );

  testWidgets('submits typed credentials', (tester) async {
    when(() => cubit.state).thenReturn(const LoginState());
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(const Key('login_username')), 'emilys');
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'emilyspass',
    );
    await tester.tap(find.byKey(const Key('login_submit')));

    verify(
      () => cubit.submit(username: 'emilys', password: 'emilyspass'),
    ).called(1);
  });

  testWidgets(
    'AUTH-001 AC-5: disables button and shows spinner while submitting',
    (
      tester,
    ) async {
      when(
        () => cubit.state,
      ).thenReturn(const LoginState(status: LoginStatus.submitting));
      await tester.pumpWidget(wrap());

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('login_submit')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('AUTH-001 AC-2: shows error message', (tester) async {
    when(() => cubit.state).thenReturn(
      const LoginState(status: LoginStatus.failure, errorMessage: 'Oops'),
    );
    await tester.pumpWidget(wrap());

    expect(find.text('Oops'), findsOneWidget);
  });

  testWidgets('AUTH-001 AC-1: navigates to profile on success', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable(const [
        LoginState(status: LoginStatus.success, user: tUser),
      ]),
      initialState: const LoginState(),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
  });

  group('redesigned login page', () {
    const submitting = LoginState(status: LoginStatus.submitting);

    testWidgets('shows title as a semantics header, no AppBar', (tester) async {
      final semantics = tester.ensureSemantics();
      when(() => cubit.state).thenReturn(const LoginState());
      await tester.pumpWidget(wrap());

      expect(find.byKey(const Key('login_title')), findsOneWidget);
      expect(find.text('Login'), findsNWidgets(2)); // title + button label
      expect(find.byType(AppBar), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(const Key('login_title')))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('forgot password shows "not available" snackbar', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(const LoginState());
      await tester.pumpWidget(wrap());

      await tester.tap(find.byKey(const Key('login_forgot_password')));
      await tester.pump();

      expect(find.text('Password reset is not available yet.'), findsOneWidget);
      verifyNever(
        () => cubit.submit(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('google button shows "not available" snackbar', (tester) async {
      when(() => cubit.state).thenReturn(const LoginState());
      await tester.pumpWidget(wrap());

      await tester.tap(find.byKey(const Key('login_google')));
      await tester.pump();

      expect(find.text('Google sign-in is not available yet.'), findsOneWidget);
      verifyNever(
        () => cubit.submit(
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      );
    });

    testWidgets('a second snackbar replaces the first', (tester) async {
      when(() => cubit.state).thenReturn(const LoginState());
      await tester.pumpWidget(wrap());

      await tester.tap(find.byKey(const Key('login_forgot_password')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login_google')));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Google sign-in is not available yet.'), findsOneWidget);
      expect(find.text('Password reset is not available yet.'), findsNothing);
    });

    testWidgets('forgot, google, and fields are disabled while submitting', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(submitting);
      await tester.pumpWidget(wrap());

      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('login_forgot_password')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.descendant(
                of: find.byKey(const Key('login_google')),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      expect(fields.every((f) => f.enabled == false), isTrue);

      await tester.tap(
        find.byKey(const Key('login_forgot_password')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('username field exposes semantics label "Username"', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      when(() => cubit.state).thenReturn(const LoginState());
      await tester.pumpWidget(wrap());

      // Flutter appends the hint to the field's label ("Username\nEnter ..."),
      // so match the start; exactly one node means the visible label Text is
      // not announced separately.
      expect(find.bySemanticsLabel(RegExp('^Username')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('360x640 at 1.3x text scale: no overflow, buttons reachable', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(() => cubit.state).thenReturn(
        const LoginState(status: LoginStatus.failure, errorMessage: 'Oops'),
      );
      await tester.pumpWidget(wrap(textScale: 1.3));
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const Key('login_google')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('login_google')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login_submit')));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('login_submit')));
      verify(
        () => cubit.submit(username: '', password: ''),
      ).called(1);
    });

    testWidgets('renders in dark theme without exceptions', (tester) async {
      when(() => cubit.state).thenReturn(const LoginState());
      await tester.pumpWidget(wrap(theme: AppTheme.dark()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(find.byKey(const Key('login_google')), findsOneWidget);
    });
  });
}
