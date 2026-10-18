import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'demo_api.dart';
import 'profile.dart';
import 'scheduler.dart';

/// The same network engine is used by the Dio adapter and shelf server. Latency
/// is asynchronous; the body is rate-limited in independently awaited chunks.
final class SimulatedTransport {
  SimulatedTransport({
    DemoApi? api,
    this.profile = NetworkProfile.normal,
    SimulationScheduler? scheduler,
    this.seed = 42,
    this.faults = const [],
    this.maxLogEntries = 1000,
  }) : _api = api,
       scheduler = scheduler ?? RealSimulationScheduler();

  DemoApi? _api;
  DemoApi get api => _api ??= DemoApi();
  NetworkProfile profile;
  final SimulationScheduler scheduler;
  final int seed;
  final List<FaultRule> faults;
  final int maxLogEntries;
  final List<RequestEvent> _events = [];
  final Map<int, int> _ruleOccurrences = {};
  int _sequence = 0;

  List<RequestEvent> get events => List.unmodifiable(_events);
  void clearLog() => _events.clear();

  Map<String, Object> diagnostics({required String cacheState}) => {
    'source': 'simulation',
    'seed': seed,
    'profile': profile.toJson(),
    'cacheState': cacheState,
    'events': events.map((event) => event.toJson()).toList(growable: false),
  };

  Future<SimulatedExchange> open(
    SimulatedRequest request,
    SimulationCancellation cancellation,
  ) async {
    final requestId = ++_sequence;
    final capturedProfile = profile;
    final random = Random(seed + requestId * 104729);
    void log(String phase, {int bytes = 0}) => _log(
      RequestEvent(
        requestId: requestId,
        method: request.method,
        path: request.path,
        phase: phase,
        elapsed: scheduler.elapsed,
        profile: capturedProfile.name,
        bytes: bytes,
      ),
    );
    log('started');
    final nextPage = request.query['cursor'] != null;
    final rule = _matchRule(request, nextPage);
    final latency =
        rule?.latency ?? capturedProfile.latency(random, nextPage: nextPage);
    final fault = rule?.fault ?? _randomFault(capturedProfile, random);
    try {
      cancellation.throwIfCancelled();
      await scheduler.delay(latency, cancellation);
      cancellation.throwIfCancelled();
      if (fault == SimulatedFault.offline || capturedProfile.isOffline) {
        throw const SimulatedConnectionFailure('offline');
      }
      if (fault == SimulatedFault.timeout) {
        // A deterministic transport timeout is an event, not a 30-second test
        // sleep. Real transport timeouts remain Dio's responsibility.
        throw const SimulatedTimeout();
      }
      final response = fault == SimulatedFault.httpError
          ? SimulatedResponse({
              'error': {
                'code': 'temporarily_unavailable',
                'message': DemoTexts.text(
                  request.language,
                  'error.unavailable',
                ),
              },
            }, statusCode: 503)
          : await api.handle(request);
      cancellation.throwIfCancelled();
      if (fault == SimulatedFault.lostResponse) {
        // The handler has already committed. Consumers must reconcile by the
        // existing idempotency key rather than treat this as a rejected payment.
        throw const SimulatedTimeout();
      }
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(response.body)));
      log('headers');
      return SimulatedExchange(
        statusCode: response.statusCode,
        contentLength: bytes.length,
        stream: _body(bytes, capturedProfile, fault, cancellation, log),
      );
    } on SimulationCancelled {
      log('cancelled');
      rethrow;
    } on SimulatedTimeout {
      log('timeout');
      rethrow;
    } on SimulatedConnectionFailure {
      log('failed');
      rethrow;
    }
  }

  Stream<Uint8List> _body(
    Uint8List bytes,
    NetworkProfile profile,
    SimulatedFault? fault,
    SimulationCancellation cancellation,
    void Function(String, {int bytes}) log,
  ) async* {
    var sent = 0;
    try {
      for (
        var offset = 0;
        offset < bytes.length;
        offset += profile.chunkBytes
      ) {
        cancellation.throwIfCancelled();
        if (fault == SimulatedFault.disconnect && sent >= bytes.length ~/ 2) {
          throw const SimulatedConnectionFailure('disconnected');
        }
        final end = min(offset + profile.chunkBytes, bytes.length);
        final chunk = Uint8List.sublistView(bytes, offset, end);
        await scheduler.delay(
          Duration(
            microseconds:
                (chunk.length *
                        Duration.microsecondsPerSecond /
                        profile.bytesPerSecond)
                    .ceil(),
          ),
          cancellation,
        );
        cancellation.throwIfCancelled();
        sent += chunk.length;
        log('chunk', bytes: chunk.length);
        yield chunk;
      }
      log('completed', bytes: sent);
    } on SimulationCancelled {
      log('cancelled', bytes: sent);
      return;
    } on SimulatedConnectionFailure {
      log('failed', bytes: sent);
      rethrow;
    }
  }

  FaultRule? _matchRule(SimulatedRequest request, bool nextPage) {
    for (var index = 0; index < faults.length; index++) {
      final rule = faults[index];
      if (rule.path.replaceFirst(RegExp(r'^/v1(?=/)'), '') != request.path ||
          (rule.method != null && rule.method != request.method) ||
          (rule.nextPage != null && rule.nextPage != nextPage)) {
        continue;
      }
      final occurrence = (_ruleOccurrences[index] ?? 0) + 1;
      _ruleOccurrences[index] = occurrence;
      if (occurrence == rule.occurrence) return rule;
    }
    return null;
  }

  SimulatedFault? _randomFault(NetworkProfile profile, Random random) {
    if (profile.isOffline) return SimulatedFault.offline;
    final draw = random.nextDouble();
    if (draw < profile.errorProbability) return SimulatedFault.httpError;
    if (draw < profile.errorProbability + profile.timeoutProbability) {
      return SimulatedFault.timeout;
    }
    if (draw <
        profile.errorProbability +
            profile.timeoutProbability +
            profile.disconnectProbability) {
      return SimulatedFault.disconnect;
    }
    return null;
  }

  void _log(RequestEvent event) {
    _events.add(event);
    if (_events.length > maxLogEntries) _events.removeAt(0);
  }
}

final class SimulatedExchange {
  const SimulatedExchange({
    required this.statusCode,
    required this.contentLength,
    required this.stream,
  });

  final int statusCode;
  final int contentLength;
  final Stream<Uint8List> stream;
}

final class SimulatedConnectionFailure implements Exception {
  const SimulatedConnectionFailure(this.reason);

  final String reason;
}

final class SimulatedTimeout implements Exception {
  const SimulatedTimeout();
}

final class SimulationAdapter implements HttpClientAdapter {
  SimulationAdapter({
    DemoApi? api,
    NetworkProfile profile = NetworkProfile.normal,
    SimulationScheduler? scheduler,
    int seed = 42,
    List<FaultRule> faults = const [],
  }) : transport = SimulatedTransport(
         api: api,
         profile: profile,
         scheduler: scheduler,
         seed: seed,
         faults: faults,
       );

  final SimulatedTransport transport;
  final Set<SimulationCancellation> _requests = {};
  bool _closed = false;

  DemoApi get api => transport.api;
  NetworkProfile get profile => transport.profile;
  set profile(NetworkProfile value) => transport.profile = value;
  List<RequestEvent> get events => transport.events;
  Future<void> resetData() => api.reset();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('SimulationAdapter is closed');
    final cancellation = SimulationCancellation();
    _requests.add(cancellation);
    if (cancelFuture != null) {
      unawaited(cancelFuture.then((_) => cancellation.cancel()));
    }
    try {
      final requestBytes = requestStream == null
          ? <int>[]
          : await requestStream.expand((chunk) => chunk).toList();
      final decoded = requestBytes.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(utf8.decode(requestBytes));
      final body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
      final exchange = await transport.open(
        SimulatedRequest(
          method: options.method,
          uri: options.uri,
          body: body,
          acceptLanguage: options.headers['accept-language'] as String?,
        ),
        cancellation,
      );
      return ResponseBody(
        _mapStream(exchange.stream, options, cancellation),
        exchange.statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          Headers.contentLengthHeader: ['${exchange.contentLength}'],
        },
        onClose: () {
          cancellation.cancel();
          _requests.remove(cancellation);
        },
      );
    } on Object catch (error, stack) {
      _requests.remove(cancellation);
      Error.throwWithStackTrace(_exception(error, options), stack);
    }
  }

  Stream<Uint8List> _mapStream(
    Stream<Uint8List> input,
    RequestOptions options,
    SimulationCancellation cancellation,
  ) async* {
    try {
      yield* input;
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(_exception(error, options), stack);
    } finally {
      _requests.remove(cancellation);
    }
  }

  DioException _exception(Object error, RequestOptions options) => DioException(
    requestOptions: options,
    type: switch (error) {
      SimulationCancelled() => DioExceptionType.cancel,
      SimulatedTimeout() => DioExceptionType.receiveTimeout,
      SimulatedConnectionFailure() => DioExceptionType.connectionError,
      _ => DioExceptionType.unknown,
    },
    error: error,
  );

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final request in _requests.toList()) {
      request.cancel();
    }
    _requests.clear();
  }
}
