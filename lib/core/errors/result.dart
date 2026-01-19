import 'app_exceptions.dart';

/// A Result type that represents either a success with data or a failure with an exception.
/// This provides a functional approach to error handling without using try-catch everywhere.
sealed class Result<T> {
  const Result();

  /// Creates a successful result with data
  factory Result.success(T data) = Success<T>;

  /// Creates a failure result with an exception
  factory Result.failure(AppException exception) = Failure<T>;

  /// Returns true if this is a success result
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is a failure result
  bool get isFailure => this is Failure<T>;

  /// Gets the data if success, otherwise returns null
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Failure() => null,
      };

  /// Gets the exception if failure, otherwise returns null
  AppException? get exceptionOrNull => switch (this) {
        Success() => null,
        Failure(:final exception) => exception,
      };

  /// Maps the success value to a new type
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success(:final data) => Result.success(transform(data)),
        Failure(:final exception) => Result.failure(exception),
      };

  /// Maps the success value to a new Result
  Result<R> flatMap<R>(Result<R> Function(T data) transform) => switch (this) {
        Success(:final data) => transform(data),
        Failure(:final exception) => Result.failure(exception),
      };

  /// Transforms the exception if this is a failure
  Result<T> mapError(AppException Function(AppException exception) transform) =>
      switch (this) {
        Success() => this,
        Failure(:final exception) => Result.failure(transform(exception)),
      };

  /// Executes the appropriate callback based on the result
  R when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) =>
      switch (this) {
        Success(:final data) => success(data),
        Failure(:final exception) => failure(exception),
      };

  /// Executes callbacks with nullable returns
  R? whenOrNull<R>({
    R Function(T data)? success,
    R Function(AppException exception)? failure,
  }) =>
      switch (this) {
        Success(:final data) => success?.call(data),
        Failure(:final exception) => failure?.call(exception),
      };

  /// Gets the data or throws the exception
  T getOrThrow() => switch (this) {
        Success(:final data) => data,
        Failure(:final exception) => throw exception,
      };

  /// Gets the data or returns a default value
  T getOrElse(T defaultValue) => switch (this) {
        Success(:final data) => data,
        Failure() => defaultValue,
      };

  /// Gets the data or computes a default value
  T getOrElseCompute(T Function(AppException exception) compute) =>
      switch (this) {
        Success(:final data) => data,
        Failure(:final exception) => compute(exception),
      };

  /// Executes a side effect if success
  Result<T> onSuccess(void Function(T data) action) {
    if (this case Success(:final data)) {
      action(data);
    }
    return this;
  }

  /// Executes a side effect if failure
  Result<T> onFailure(void Function(AppException exception) action) {
    if (this case Failure(:final exception)) {
      action(exception);
    }
    return this;
  }
}

/// Represents a successful result
final class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// Represents a failure result
final class Failure<T> extends Result<T> {
  final AppException exception;

  const Failure(this.exception);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          exception == other.exception;

  @override
  int get hashCode => exception.hashCode;

  @override
  String toString() => 'Failure($exception)';
}

/// Extension for async Result handling
extension ResultFutureExtension<T> on Future<Result<T>> {
  /// Awaits the future and executes the appropriate callback
  Future<R> when<R>({
    required R Function(T data) success,
    required R Function(AppException exception) failure,
  }) async {
    final result = await this;
    return result.when(success: success, failure: failure);
  }
}

/// Helper function to wrap async operations in a Result
Future<Result<T>> runCatching<T>(Future<T> Function() operation) async {
  try {
    final data = await operation();
    return Result.success(data);
  } on AppException catch (e) {
    return Result.failure(e);
  } catch (e, stackTrace) {
    return Result.failure(
      UnknownException(
        message: e.toString(),
        originalError: e,
        stackTrace: stackTrace,
      ),
    );
  }
}

/// Helper function for sync operations
Result<T> runCatchingSync<T>(T Function() operation) {
  try {
    final data = operation();
    return Result.success(data);
  } on AppException catch (e) {
    return Result.failure(e);
  } catch (e, stackTrace) {
    return Result.failure(
      UnknownException(
        message: e.toString(),
        originalError: e,
        stackTrace: stackTrace,
      ),
    );
  }
}
