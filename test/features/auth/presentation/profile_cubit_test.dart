import 'package:bloc_test/bloc_test.dart';
import 'package:demo_ai_workflow/core/error/failures.dart';
import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockGetProfileUseCase getProfile;
  late MockLogoutUseCase logout;

  setUp(() {
    getProfile = MockGetProfileUseCase();
    logout = MockLogoutUseCase();
    when(() => logout()).thenAnswer((_) async {});
  });

  ProfileCubit build() => ProfileCubit(getProfile: getProfile, logout: logout);

  blocTest<ProfileCubit, ProfileState>(
    'AUTH-001 AC-6: loads profile',
    setUp: () => when(
      () => getProfile(),
    ).thenAnswer((_) async => const Success(tUser)),
    build: build,
    act: (c) => c.load(),
    expect: () => const [ProfileLoading(), ProfileLoaded(tUser)],
  );

  blocTest<ProfileCubit, ProfileState>(
    'AUTH-001 AC-7: flags session expiry so UI can redirect to login',
    setUp: () => when(
      () => getProfile(),
    ).thenAnswer((_) async => const Failed(UnauthorizedFailure())),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ProfileLoading(),
      ProfileError(
        const UnauthorizedFailure().message,
        sessionExpired: true,
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'shows retryable error on network failure',
    setUp: () => when(
      () => getProfile(),
    ).thenAnswer((_) async => const Failed(NetworkFailure())),
    build: build,
    act: (c) => c.load(),
    expect: () => [
      const ProfileLoading(),
      ProfileError(const NetworkFailure().message),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'AUTH-001 AC-6: logout clears session',
    build: build,
    act: (c) => c.logout(),
    expect: () => const [ProfileLoggedOut()],
    verify: (_) => verify(() => logout()).called(1),
  );
}
