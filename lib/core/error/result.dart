import 'package:demo_ai_workflow/core/error/failures.dart';

/// Minimal Result type: forces callers to handle both outcomes via
/// exhaustive `switch` on the sealed class.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);

  final Failure failure;
}
