enum ApiFailureKind {
  cancelled,
  timeout,
  offline,
  unavailable,
  validation,
  conflict,
  notFound,
  invalidResponse,
}

/// A consumer can distinguish cancellation from a failed operation, and a
/// timeout from a definite server rejection. No request body is retained.
final class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.message,
    required this.retryable,
    this.code,
    this.statusCode,
  });

  final ApiFailureKind kind;
  final String message;
  final bool retryable;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiFailure(${kind.name}, $code, $message)';
}
