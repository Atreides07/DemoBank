import 'dart:math';

enum SimulatedFault { httpError, timeout, offline, disconnect, lostResponse }

final class NetworkProfile {
  const NetworkProfile({
    required this.name,
    required this.firstByteLatency,
    required this.jitter,
    required this.bytesPerSecond,
    this.chunkBytes = 2048,
    this.pageExtraLatency = Duration.zero,
    this.errorProbability = 0,
    this.timeoutProbability = 0,
    this.disconnectProbability = 0,
    this.isOffline = false,
  }) : assert(bytesPerSecond > 0),
       assert(chunkBytes > 0),
       assert(errorProbability >= 0 && errorProbability <= 1),
       assert(timeoutProbability >= 0 && timeoutProbability <= 1),
       assert(disconnectProbability >= 0 && disconnectProbability <= 1);

  static const normal = NetworkProfile(
    name: 'normal',
    firstByteLatency: Duration(milliseconds: 120),
    jitter: Duration(milliseconds: 30),
    bytesPerSecond: 512000,
  );
  static const slow = NetworkProfile(
    name: 'slow',
    firstByteLatency: Duration(milliseconds: 1100),
    jitter: Duration(milliseconds: 300),
    bytesPerSecond: 18000,
    chunkBytes: 1024,
    pageExtraLatency: Duration(milliseconds: 800),
  );
  static const unstable = NetworkProfile(
    name: 'unstable',
    firstByteLatency: Duration(milliseconds: 650),
    jitter: Duration(milliseconds: 450),
    bytesPerSecond: 24000,
    chunkBytes: 1024,
    pageExtraLatency: Duration(milliseconds: 500),
    errorProbability: 0.12,
    timeoutProbability: 0.06,
    disconnectProbability: 0.06,
  );
  static const offline = NetworkProfile(
    name: 'offline',
    firstByteLatency: Duration(milliseconds: 100),
    jitter: Duration.zero,
    bytesPerSecond: 1,
    isOffline: true,
  );

  final String name;
  final Duration firstByteLatency;
  final Duration jitter;
  final int bytesPerSecond;
  final int chunkBytes;
  final Duration pageExtraLatency;
  final double errorProbability;
  final double timeoutProbability;
  final double disconnectProbability;
  final bool isOffline;

  Duration latency(Random random, {required bool nextPage}) {
    final spread = jitter.inMicroseconds;
    final delta = spread == 0 ? 0 : random.nextInt(spread * 2 + 1) - spread;
    return Duration(
      microseconds:
          max(0, firstByteLatency.inMicroseconds + delta) +
          (nextPage ? pageExtraLatency.inMicroseconds : 0),
    );
  }

  Map<String, Object> toJson() => {
    'name': name,
    'firstByteLatencyMs': firstByteLatency.inMilliseconds,
    'jitterMs': jitter.inMilliseconds,
    'bytesPerSecond': bytesPerSecond,
    'chunkBytes': chunkBytes,
    'pageExtraLatencyMs': pageExtraLatency.inMilliseconds,
    'errorProbability': errorProbability,
    'timeoutProbability': timeoutProbability,
    'disconnectProbability': disconnectProbability,
    'offline': isOffline,
  };
}

/// Matching counts are scoped to the rule, so a single page failure can be
/// followed by a successful retry with exactly the same cursor.
final class FaultRule {
  const FaultRule({
    required this.path,
    this.method,
    this.occurrence = 1,
    this.nextPage,
    this.fault,
    this.latency,
  }) : assert(occurrence > 0);

  final String path;
  final String? method;
  final int occurrence;
  final bool? nextPage;
  final SimulatedFault? fault;
  final Duration? latency;
}

final class RequestEvent {
  const RequestEvent({
    required this.requestId,
    required this.method,
    required this.path,
    required this.phase,
    required this.elapsed,
    required this.profile,
    this.bytes = 0,
  });

  final int requestId;
  final String method;

  /// Paths only: document numbers, phone numbers, payloads and query values are
  /// deliberately excluded from diagnostic logs.
  final String path;
  final String phase;
  final Duration elapsed;
  final String profile;
  final int bytes;

  Map<String, Object> toJson() => {
    'requestId': requestId,
    'method': method,
    'path': path,
    'phase': phase,
    'elapsedUs': elapsed.inMicroseconds,
    'profile': profile,
    'bytes': bytes,
  };
}
