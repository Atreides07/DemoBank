import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_failure.dart';
import 'api_request_event.dart';

export 'api_failure.dart';

typedef ApiRequestObserver = FutureOr<void> Function(ApiRequestEvent event);

final class RequestCancellation {
  final CancelToken _token = CancelToken();

  bool get isCancelled => _token.isCancelled;

  void cancel() => _token.cancel('Request scope disposed');
}

/// Normal serialization and response transformation are shared by the real and
/// simulated adapters. Transports are selected only at the composition root.
final class ApiClient {
  ApiClient({
    required Uri baseUri,
    HttpClientAdapter? adapter,
    ApiRequestObserver? onEvent,
    this.persistentConnection = true,
    String acceptLanguage = 'ru',
  }) : _onEvent = onEvent,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUri.toString().replaceFirst(RegExp(r'/$'), ''),
           connectTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
           persistentConnection: persistentConnection,
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
           headers: {
             'accept': Headers.jsonContentType,
             'accept-language': acceptLanguage,
           },
         ),
       ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    if (onEvent != null) {
      _dio.httpClientAdapter = _ObservedAdapter(_dio.httpClientAdapter);
    }
  }

  final Dio _dio;
  final ApiRequestObserver? _onEvent;

  /// Native HTTP request policy. False requests connection closure after each
  /// response; custom adapters and browser transports may not use this option.
  /// The ordinary pooled transport remains the default.
  final bool persistentConnection;
  int _requestSequence = 0;
  bool _closed = false;

  /// Language of user-facing content in responses (names, descriptions and
  /// rejection messages). Changing it affects only requests started later.
  String get acceptLanguage =>
      _dio.options.headers['accept-language'] as String? ?? 'ru';

  set acceptLanguage(String value) =>
      _dio.options.headers['accept-language'] = value;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic> query = const {},
    RequestCancellation? cancellation,
  }) => _request('GET', path, query: query, cancellation: cancellation);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> data = const {},
    RequestCancellation? cancellation,
  }) => _request('POST', path, data: data, cancellation: cancellation);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
    RequestCancellation? cancellation,
  }) async {
    if (_closed) {
      throw StateError('ApiClient is closed');
    }
    final observer = _onEvent;
    final trace = observer == null
        ? null
        : _RequestTrace(
            observer: observer,
            method: method,
            path: _safePath(path),
            requestId: ++_requestSequence,
          );
    trace?.started();
    try {
      final response = await _dio.request<Object?>(
        path,
        queryParameters: {
          for (final entry in query.entries)
            if (entry.value != null)
              entry.key: entry.value is Iterable
                  ? (entry.value as Iterable<Object?>).join(',')
                  : entry.value,
        },
        data: data,
        cancelToken: cancellation?._token,
        options: Options(
          method: method,
          extra: trace == null ? null : {_traceKey: trace},
        ),
      );
      final body = response.data;
      if (body is! Map) {
        throw const ApiFailure(
          kind: ApiFailureKind.invalidResponse,
          retryable: false,
        );
      }
      final result = Map<String, dynamic>.from(body);
      trace?.finish(ApiRequestPhase.completed);
      return result;
    } on DioException catch (error) {
      final failure = _mapFailure(error);
      trace?.failure(failure.kind);
      throw failure;
    } on FormatException {
      trace?.failure(ApiFailureKind.invalidResponse);
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        retryable: false,
      );
    } on ApiFailure catch (failure) {
      trace?.failure(failure.kind);
      rethrow;
    } on Object {
      trace?.finish(ApiRequestPhase.failed);
      rethrow;
    }
  }

  ApiFailure _mapFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return const ApiFailure(
          kind: ApiFailureKind.cancelled,
          retryable: false,
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiFailure(kind: ApiFailureKind.timeout, retryable: true);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const ApiFailure(kind: ApiFailureKind.offline, retryable: true);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final body = error.response?.data;
        final details = body is Map ? body['error'] : null;
        final code = details is Map ? details['code']?.toString() : null;
        final message = details is Map ? details['message']?.toString() : null;
        return ApiFailure(
          kind: switch (status) {
            408 || 504 => ApiFailureKind.timeout,
            400 || 422 => ApiFailureKind.validation,
            404 => ApiFailureKind.notFound,
            409 => ApiFailureKind.conflict,
            _ => ApiFailureKind.unavailable,
          },
          serverMessage: message,
          retryable: status == 408 || status == 429 || (status ?? 500) >= 500,
          code: code,
          statusCode: status,
        );
      case DioExceptionType.unknown:
        return ApiFailure(
          kind: error.error is FormatException
              ? ApiFailureKind.invalidResponse
              : ApiFailureKind.offline,
          retryable: error.error is! FormatException,
        );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _dio.close(force: true);
  }
}

const _traceKey = 'network_client.private.requestTrace';

/// Header timing is captured before Dio transforms/decodes the response body;
/// its response interceptor would run too late to measure time to headers.
final class _ObservedAdapter implements HttpClientAdapter {
  _ObservedAdapter(this._delegate);
  final HttpClientAdapter _delegate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final trace = options.extra[_traceKey] as _RequestTrace?;
    final response = await _delegate.fetch(
      options,
      requestStream,
      cancelFuture,
    );
    trace?.headers();
    if (trace != null) {
      response.stream = response.stream.map((chunk) {
        trace.received(chunk.length);
        return chunk;
      });
    }
    return response;
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}

final class _RequestTrace {
  _RequestTrace({
    required this.observer,
    required this.method,
    required this.path,
    required this.requestId,
  });
  final ApiRequestObserver observer;
  final String method;
  final String path;
  final int requestId;
  final Stopwatch _watch = Stopwatch()..start();
  int _receivedBytes = 0;
  bool _finished = false;

  void started() => _emit(ApiRequestPhase.started);
  void headers() => _emit(ApiRequestPhase.headers);
  void received(int count) {
    if (_finished) return;
    _receivedBytes += count;
    _emit(ApiRequestPhase.chunk);
  }

  void failure(ApiFailureKind kind) => finish(
    kind == ApiFailureKind.cancelled
        ? ApiRequestPhase.cancelled
        : ApiRequestPhase.failed,
    failureKind: kind,
  );

  void finish(ApiRequestPhase phase, {ApiFailureKind? failureKind}) {
    if (_finished) return;
    _watch.stop();
    _emit(phase, failureKind: failureKind);
    _finished = true;
  }

  void _emit(ApiRequestPhase phase, {ApiFailureKind? failureKind}) {
    if (_finished) return;
    final event = ApiRequestEvent(
      method: method,
      path: path,
      requestId: requestId,
      phase: phase,
      elapsed: _watch.elapsed,
      bytes: _receivedBytes,
      failureKind: failureKind,
    );
    try {
      final result = observer(event);
      if (result is Future<void>) {
        unawaited(
          result.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        );
      }
    } on Object {
      // Observability cannot turn a successful payment or read into a failure.
      // Error details are intentionally not logged: they may contain payloads.
    }
  }
}

String _safePath(String path) {
  // Only known static route vocabulary is retained. Unknown segments, including
  // arbitrary alphabetic operation keys, are never emitted as metric labels.
  const staticSegments = {
    'api',
    'v1',
    'v2',
    'health',
    'accounts',
    'transactions',
    'analytics',
    'services',
    'fines',
    'utilities',
    'operators',
    'movies',
    'sessions',
    'seats',
    'checkout',
    'quotes',
    'payments',
    'status',
    'demo',
    'activity',
    'operations',
    'receipt',
    'receipts',
    'confirm',
    'cancel',
    'lookup',
    'users',
    'customers',
    'documents',
    'phones',
  };
  const collections = {
    'accounts',
    'transactions',
    'fines',
    'utilities',
    'operators',
    'movies',
    'sessions',
    'seats',
    'quotes',
    'payments',
    'operations',
    'receipts',
    'users',
    'customers',
    'documents',
    'phones',
  };
  const fixedRoutes = {
    'health',
    'accounts',
    'transactions',
    'analytics',
    'services',
    'services/fines',
    'services/utilities',
    'services/operators',
    'services/movies',
    'services/sessions',
    'services/seats',
    'checkout/quotes',
    'checkout/payments',
    'checkout/payments/status',
    'demo/activity',
  };
  try {
    final uri = Uri.tryParse(path);
    if (uri == null) return '/:redacted';
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final unversioned =
        segments.isNotEmpty && const {'v1', 'v2'}.contains(segments.first)
        ? segments.skip(1).join('/')
        : segments.join('/');
    if (fixedRoutes.contains(unversioned)) return '/${segments.join('/')}';
    var redactNext = false;
    final safe = <String>[];
    for (final segment in segments) {
      safe.add(
        redactNext || !staticSegments.contains(segment) ? ':id' : segment,
      );
      redactNext = collections.contains(segment);
    }
    return '/${safe.join('/')}';
  } on FormatException {
    return '/:redacted';
  }
}
