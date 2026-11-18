import 'package:equatable/equatable.dart';

/// Domain-level failures. The UI only ever sees these, never Dio/Platform
/// exceptions.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure()
    : super('Username or password is incorrect.');
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure()
    : super('Your session has expired. Please log in again.');
}

final class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection. Please try again.');
}

final class StorageFailure extends Failure {
  const StorageFailure()
    : super('Could not access secure storage. Please try again.');
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong. Please retry.']);
}
