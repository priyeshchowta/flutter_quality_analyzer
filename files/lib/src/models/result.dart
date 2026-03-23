/// A simple Result type to represent success or failure without throwing exceptions.
///
/// Usage:
///   Result<String> result = Result.success('hello');
///   Result<String> fail   = Result.failure('Something went wrong');
///
///   if (result.isSuccess) print(result.value);
///   if (fail.isFailure)   print(fail.error);
class Result<T> {
  final T? value;
  final String? error;

  const Result._({this.value, this.error});

  /// Creates a successful result holding [value].
  factory Result.success(T value) => Result._(value: value);

  /// Creates a failure result holding an [error] message.
  factory Result.failure(String error) => Result._(error: error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  @override
  String toString() => isSuccess ? 'Result.success($value)' : 'Result.failure($error)';
}
