import 'api_failure.dart';

enum ApiRequestPhase { started, headers, chunk, completed, failed, cancelled }

/// Client-side, real elapsed time for either HTTP or an injected adapter.
///
/// [bytes] is the cumulative body size observed at the adapter boundary. It is
/// not an estimate of wire bytes (platform decompression may already apply).
/// The event contains no URL origin, query, headers, payload, or error message.
final class ApiRequestEvent {
  const ApiRequestEvent({
    required this.method,
    required this.path,
    required this.requestId,
    required this.phase,
    required this.elapsed,
    this.bytes,
    this.failureKind,
  });

  final String method;
  final String path;
  final int requestId;
  final ApiRequestPhase phase;
  final Duration elapsed;
  final int? bytes;
  final ApiFailureKind? failureKind;

  Map<String, Object> toJson() => {
    'method': method,
    'path': path,
    'requestId': requestId,
    'phase': phase.name,
    'elapsedUs': elapsed.inMicroseconds,
    if (bytes != null) 'bytes': bytes!,
    if (failureKind != null) 'failureKind': failureKind!.name,
  };
}
