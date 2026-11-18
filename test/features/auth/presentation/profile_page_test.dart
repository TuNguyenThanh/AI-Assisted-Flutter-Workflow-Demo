import 'package:bloc_test/bloc_test.dart';
import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/profile_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/login_page.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

void main() {
  late MockProfileCubit cubit;

  setUp(() {
    cubit = MockProfileCubit();
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.logout()).thenAnswer((_) async {});
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<ProfileCubit>.value(
      value: cubit,
      child: const ProfilePage(),
    ),
    routes: {
      LoginPage.routeName: (_) => const Scaffold(body: Text('LOGIN')),
    },
  );

  testWidgets('shows spinner while loading', (tester) async {
    when(() => cubit.state).thenReturn(const ProfileLoading());
    await tester.pumpWidget(wrap());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AUTH-001 AC-6: shows user details', (tester) async {
    when(() => cubit.state).thenReturn(const ProfileLoaded(tUser));
    await tester.pumpWidget(wrap());

    expect(find.byKey(const Key('profile_name')), findsOneWidget);
    expect(find.text('Emily Johnson'), findsOneWidget);
    expect(find.text('emilys'), findsOneWidget);
    expect(find.text(tUser.email), findsOneWidget);
  });

  testWidgets('error state offers retry', (tester) async {
    when(() => cubit.state).thenReturn(const ProfileError('Offline'));
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Retry'));

    expect(find.text('Offline'), findsOneWidget);
    verify(() => cubit.load()).called(1);
  });

  testWidgets('AUTH-001 AC-6: logout button calls cubit', (tester) async {
    when(() => cubit.state).thenReturn(const ProfileLoaded(tUser));
    await tester.pumpWidget(wrap());

    await tester.tap(find.byKey(const Key('profile_logout')));

    verify(() => cubit.logout()).called(1);
  });

  testWidgets('AUTH-001 AC-6: navigates to login after logout', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable(const [ProfileLoggedOut()]),
      initialState: const ProfileLoaded(tUser),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('AUTH-001 AC-7: navigates to login when session expired', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream.fromIterable(const [
        ProfileError('expired', sessionExpired: true),
      ]),
      initialState: const ProfileLoading(),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
