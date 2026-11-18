part of 'profile_cubit.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

final class ProfileError extends ProfileState {
  const ProfileError(this.message, {this.sessionExpired = false});

  final String message;
  final bool sessionExpired;

  @override
  List<Object?> get props => [message, sessionExpired];
}

final class ProfileLoggedOut extends ProfileState {
  const ProfileLoggedOut();
}
