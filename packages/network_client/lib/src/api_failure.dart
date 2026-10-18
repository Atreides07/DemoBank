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
///
/// There is no client-side display text: screens describe [kind] in the
/// current language. [serverMessage] is the server's explanation of a
/// rejection, in the language the request asked for.
final class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.retryable,
    this.serverMessage,
    this.code,
    this.statusCode,
  });

  final ApiFailureKind kind;
  final bool retryable;
  final String? serverMessage;
  final String? code;
  final int? statusCode;

  @override
  String toString() => 'ApiFailure(${kind.name}, $code)';
}
