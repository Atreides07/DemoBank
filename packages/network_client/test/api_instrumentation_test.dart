import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:network_client/network_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'events redact dynamic identifiers and contain no credentials, payload, query or error text',
    () async {
      final events = <ApiRequestEvent>[];
      final adapter = _StaticAdapter();
      final client = ApiClient(
        baseUri: Uri.parse(
          'https://base-user-private:base-password-private@demo.invalid',
        ),
        adapter: adapter,
        onEvent: events.add,
      );
      addTearDown(client.close);
      await client.post(
        '/v1/checkout/payments/paymentAlphabetPrivate/receipts/receiptAlphabetPrivate?document=document-private',
        data: {'name': 'name-private', 'phone': 'phone-private'},
      );
      await client.get(
        '/v1/checkout/payments/status',
        query: {
          'idempotencyKey': 'idempotency-private',
          'nested': ['list-value-private'],
        },
      );
      adapter
        ..status = 503
        ..body = {
          'error': {'code': 'temporary', 'message': 'provider-private'},
        };
      await expectLater(
        client.get('/v1/receipts/anotherReceiptPrivate?token=token-private'),
        throwsA(isA<ApiFailure>()),
      );
      final encoded = jsonEncode(
        events.map((event) => event.toJson()).toList(),
      );
      for (final secret in [
        'base-user-private',
        'base-password-private',
        'paymentAlphabetPrivate',
        'receiptAlphabetPrivate',
        'document-private',
        'name-private',
        'phone-private',
        'idempotency-private',
        'list-value-private',
        'provider-private',
        'anotherReceiptPrivate',
        'token-private',
        'header-private',
      ]) {
        expect(encoded, isNot(contains(secret)), reason: secret);
      }
      expect(events.first.path, '/v1/checkout/payments/:id/receipts/:id');
      expect(
        events.where((event) => event.requestId == 2).first.path,
        '/v1/checkout/payments/status',
      );
      expect(events.last.path, '/v1/receipts/:id');
      expect(events.last.phase, ApiRequestPhase.failed);
      expect(events.last.failureKind, ApiFailureKind.unavailable);
      expect(events.map((event) => event.requestId).toSet(), {1, 2, 3});
      for (final event in events) {
        expect(
          event.toJson().keys,
          everyElement(
            isIn({
              'method',
              'path',
              'requestId',
              'phase',
              'elapsedUs',
              'bytes',
              'failureKind',
            }),
          ),
        );
      }
    },
  );

  test(
    'controlled adapter and actual HTTP expose headers and progressive bytes before JSON completion',
    () async {
      final payload = Uint8List.fromList(
        utf8.encode('{"items":[1,2,3],"source":"transport"}'),
      );
      final split = payload.length ~/ 2;
      final simulatedEvents = <ApiRequestEvent>[];
      final simulatedHeaders = Completer<void>();
      final simulatedChunk = Completer<void>();
      final simulatedAdapter = _GateAdapter(payload.length);
      final simulated = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: simulatedAdapter,
        onEvent: (event) {
          simulatedEvents.add(event);
          _signal(event, simulatedHeaders, simulatedChunk);
        },
      );
      addTearDown(simulated.close);
      var simulatedCompleted = false;
      final simulatedResult = simulated.get('/v1/transactions').then((value) {
        simulatedCompleted = true;
        return value;
      });
      await simulatedHeaders.future.timeout(const Duration(seconds: 5));
      expect(simulatedEvents.map((event) => event.phase), [
        ApiRequestPhase.started,
        ApiRequestPhase.headers,
      ]);
      expect(simulatedCompleted, isFalse);
      simulatedAdapter.controller.add(Uint8List.sublistView(payload, 0, split));
      await simulatedChunk.future.timeout(const Duration(seconds: 5));
      expect(simulatedCompleted, isFalse);
      simulatedAdapter.controller.add(Uint8List.sublistView(payload, split));
      await simulatedAdapter.controller.close();
      expect((await simulatedResult)['items'], [1, 2, 3]);
      _expectCompleteTrace(simulatedEvents, payload.length);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final finish = Completer<void>();
      final served = Completer<void>();
      var disposed = false;
      final subscription = server.listen((request) {
        unawaited(() async {
          try {
            await request.drain<void>();
            request.response
              ..bufferOutput = false
              ..headers.contentType = ContentType.json
              ..contentLength = payload.length
              ..add(Uint8List.sublistView(payload, 0, split));
            await request.response.flush();
            await finish.future;
            request.response.add(Uint8List.sublistView(payload, split));
            await request.response.close();
            if (!served.isCompleted) served.complete();
          } on Object catch (error, stack) {
            if (!served.isCompleted) {
              if (disposed) {
                served.complete();
              } else {
                served.completeError(error, stack);
              }
            }
          }
        }());
      });
      final actualEvents = <ApiRequestEvent>[];
      final actualHeaders = Completer<void>();
      final actualChunk = Completer<void>();
      final actual = ApiClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        onEvent: (event) {
          actualEvents.add(event);
          _signal(event, actualHeaders, actualChunk);
        },
      );
      try {
        var completed = false;
        final result = actual.get('/v1/transactions').then((value) {
          completed = true;
          return value;
        });
        await actualChunk.future.timeout(const Duration(seconds: 5));
        expect(actualHeaders.isCompleted, isTrue);
        expect(completed, isFalse);
        expect(actualEvents.last.phase, ApiRequestPhase.chunk);
        expect(actualEvents.last.bytes, split);
        finish.complete();
        expect((await result)['items'], [1, 2, 3]);
        await served.future;
        _expectCompleteTrace(actualEvents, payload.length);
        expect(actualEvents[1].elapsed, greaterThan(Duration.zero));
      } finally {
        disposed = true;
        if (!finish.isCompleted) finish.complete();
        actual.close();
        await server.close(force: true);
        await subscription.cancel();
      }
    },
  );

  test(
    'synchronous and asynchronous observer failures do not change success or cancellation',
    () async {
      for (final asynchronous in [false, true]) {
        final client = ApiClient(
          baseUri: Uri.parse('https://demo.invalid'),
          adapter: _StaticAdapter(),
          onEvent: (_) {
            if (asynchronous) {
              return Future<void>.error(StateError('observer failed'));
            }
            throw StateError('observer failed');
          },
        );
        try {
          expect((await client.get('/v1/accounts'))['ok'], isTrue);
          await Future<void>.delayed(Duration.zero);
        } finally {
          client.close();
        }
      }
      final events = <ApiRequestEvent>[];
      final headers = Completer<void>();
      final cancellation = RequestCancellation();
      final adapter = _GateAdapter(100);
      final client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: adapter,
        onEvent: (event) {
          events.add(event);
          if (event.phase == ApiRequestPhase.headers && !headers.isCompleted) {
            headers.complete();
          }
          if (event.phase == ApiRequestPhase.chunk) cancellation.cancel();
          throw StateError('observer failed');
        },
      );
      addTearDown(client.close);
      final pending = client.get(
        '/v1/transactions',
        cancellation: cancellation,
      );
      final checked = expectLater(
        pending,
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      await headers.future.timeout(const Duration(seconds: 5));
      adapter.controller.add(Uint8List.fromList(utf8.encode('{"partial":')));
      await checked;
      expect(events.last.phase, ApiRequestPhase.cancelled);
      expect(events.last.failureKind, ApiFailureKind.cancelled);
      expect(
        events.where((event) => event.phase == ApiRequestPhase.cancelled),
        hasLength(1),
      );
      expect(
        events.any((event) => event.phase == ApiRequestPhase.completed),
        isFalse,
      );
      expect(events.last.bytes, greaterThan(0));
    },
  );
}

void _signal(
  ApiRequestEvent event,
  Completer<void> headers,
  Completer<void> chunk,
) {
  if (event.phase == ApiRequestPhase.headers && !headers.isCompleted) {
    headers.complete();
  }
  if (event.phase == ApiRequestPhase.chunk && !chunk.isCompleted) {
    chunk.complete();
  }
}

void _expectCompleteTrace(List<ApiRequestEvent> events, int bytes) {
  expect(events.first.phase, ApiRequestPhase.started);
  expect(events[1].phase, ApiRequestPhase.headers);
  expect(
    events.where((event) => event.phase == ApiRequestPhase.chunk).length,
    greaterThanOrEqualTo(2),
  );
  expect(events.last.phase, ApiRequestPhase.completed);
  expect(events.last.bytes, bytes);
  expect(events.last.failureKind, isNull);
  for (var index = 1; index < events.length; index++) {
    expect(
      events[index].elapsed,
      greaterThanOrEqualTo(events[index - 1].elapsed),
    );
    expect(events[index].bytes, greaterThanOrEqualTo(events[index - 1].bytes!));
    expect(events[index].requestId, events.first.requestId);
  }
}

final class _StaticAdapter implements HttpClientAdapter {
  int status = 200;
  Map<String, dynamic> body = {'ok': true};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentLengthHeader: ['${bytes.length}'],
        'x-private': ['header-private'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _GateAdapter implements HttpClientAdapter {
  _GateAdapter(this.contentLength);
  final int contentLength;
  final StreamController<Uint8List> controller = StreamController<Uint8List>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    controller.stream,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      Headers.contentLengthHeader: ['$contentLength'],
    },
  );
  @override
  void close({bool force = false}) {
    if (!controller.isClosed) unawaited(controller.close());
  }
}
