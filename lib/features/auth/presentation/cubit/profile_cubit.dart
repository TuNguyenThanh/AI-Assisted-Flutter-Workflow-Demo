import 'package:demo_ai_workflow/core/error/failures.dart';
import 'package:demo_ai_workflow/core/error/result.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/get_profile_usecase.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/logout_usecase.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required GetProfileUseCase getProfile,
    required LogoutUseCase logout,
  }) : _getProfile = getProfile,
       _logout = logout,
       super(const ProfileLoading());

  final GetProfileUseCase _getProfile;
  final LogoutUseCase _logout;

  Future<void> load() async {
    emit(const ProfileLoading());
    final result = await _getProfile();
    if (isClosed) return;

    switch (result) {
      case Success(:final value):
        emit(ProfileLoaded(value));
      case Failed(:final failure):
        emit(
          ProfileError(
            failure.message,
            sessionExpired: failure is UnauthorizedFailure,
          ),
        );
    }
  }

  Future<void> logout() async {
    await _logout();
    if (isClosed) return;
    emit(const ProfileLoggedOut());
  }
}
