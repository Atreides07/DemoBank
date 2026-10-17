import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_client/network_client.dart';
import 'package:test/test.dart';

void main() {
  for (final keepAlive in [true, false]) {
    test(
      '${keepAlive ? 'default policy reuses one' : 'request-close policy uses three'} TCP connections for drained GET, POST and 503',
      () async {
        final origin = await _Origin.start();
        final client = keepAlive
            ? ApiClient(baseUri: origin.uri)
            : ApiClient(baseUri: origin.uri, persistentConnection: false);
        try {
          expect(client.persistentConnection, keepAlive);
          final first = await client.get('/v1/first', query: {'page': 1});
          expect(first['method'], 'GET');
          expect(first['query'], {'page': '1'});
          final posted = await client.post(
            '/v1/command',
            data: {'idempotencyKey': 'one-command', 'amountMinor': 12300},
          );
          expect(posted['method'], 'POST');
          expect(posted['body'], {
            'idempotencyKey': 'one-command',
            'amountMinor': 12300,
          });
          await expectLater(
            client.get('/v1/unavailable'),
            throwsA(
              isA<ApiFailure>()
                  .having(
                    (failure) => failure.kind,
                    'kind',
                    ApiFailureKind.unavailable,
                  )
                  .having((failure) => failure.statusCode, 'statusCode', 503)
                  .having(
                    (failure) => failure.code,
                    'code',
                    'fixture_unavailable',
                  )
                  .having((failure) => failure.retryable, 'retryable', true),
            ),
          );
          expect(origin.requests.map((request) => request.method), [
            'GET',
            'POST',
            'GET',
          ]);
          expect(origin.requests.map((request) => request.path), [
            '/v1/first',
            '/v1/command',
            '/v1/unavailable',
          ]);
          expect(
            origin.requests.where((request) => request.method == 'POST'),
            hasLength(1),
          );
          expect(
            origin.requests.map((request) => request.keepAlive),
            everyElement(keepAlive),
          );
          expect(
            origin.requests.map((request) => request.port).toSet(),
            hasLength(keepAlive ? 1 : 3),
          );
        } finally {
          client.close();
          await origin.close();
        }
        expect(origin.errors, isEmpty);
      },
    );

    test(
      '${keepAlive ? 'default' : 'request-close'} policy cancels an open body and permits the next request',
      () async {
        final origin = await _Origin.start();
        final chunk = Completer<void>();
        final events = <ApiRequestEvent>[];
        final client = ApiClient(
          baseUri: origin.uri,
          persistentConnection: keepAlive,
          onEvent: (event) {
            events.add(event);
            if (event.requestId == 1 &&
                event.phase == ApiRequestPhase.chunk &&
                !chunk.isCompleted) {
              chunk.complete();
            }
          },
        );
        final cancellation = RequestCancellation();
        try {
          final pending = client.get('/v1/held', cancellation: cancellation);
          final checked = expectLater(
            pending,
            throwsA(
              isA<ApiFailure>()
                  .having(
                    (failure) => failure.kind,
                    'kind',
                    ApiFailureKind.cancelled,
                  )
                  .having((failure) => failure.retryable, 'retryable', false),
            ),
          );
          await chunk.future.timeout(const Duration(seconds: 5));
          origin.expectHeldCancellation = true;
          cancellation.cancel();
          await checked.timeout(const Duration(seconds: 5));
          expect(cancellation.isCancelled, true);
          final terminals = events.where(
            (event) =>
                event.requestId == 1 &&
                {
                  ApiRequestPhase.completed,
                  ApiRequestPhase.cancelled,
                  ApiRequestPhase.failed,
                }.contains(event.phase),
          );
          expect(terminals.map((event) => event.phase), [
            ApiRequestPhase.cancelled,
          ]);
          expect((await client.get('/v1/recovered'))['method'], 'GET');
          expect(origin.requests.map((request) => request.path), [
            '/v1/held',
            '/v1/recovered',
          ]);
          expect(
            origin.requests.map((request) => request.keepAlive),
            everyElement(keepAlive),
          );
          expect(
            origin.requests.map((request) => request.port).toSet(),
            hasLength(2),
          );
        } finally {
          client.close();
          await origin.close();
        }
        expect(origin.errors, isEmpty);
      },
    );
  }
}

typedef _Request = ({String method, String path, int port, bool keepAlive});

/// Real loopback HTTP, including native response consumption and TCP lifetime.
/// No adapter substitute, retries, socket cap or external service is involved.
final class _Origin {
  _Origin._(this.server) {
    subscription = server.listen((request) {
      final pending = _handle(request);
      handlers.add(pending);
      unawaited(pending.whenComplete(() => handlers.remove(pending)));
    });
  }

  static Future<_Origin> start() async =>
      _Origin._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer server;
  late final StreamSubscription<HttpRequest> subscription;
  final requests = <_Request>[];
  final errors = <Object>[];
  final handlers = <Future<void>>{};
  final releaseHeld = Completer<void>();
  bool expectHeldCancellation = false;
  Uri get uri =>
      Uri(scheme: 'http', host: server.address.address, port: server.port);

  Future<void> _handle(HttpRequest request) async {
    try {
      requests.add((
        method: request.method,
        path: request.uri.path,
        port: request.connectionInfo!.remotePort,
        keepAlive: request.persistentConnection,
      ));
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      final unavailable = request.uri.path == '/v1/unavailable';
      final payload = utf8.encode(
        jsonEncode(
          unavailable
              ? {
                  'error': {
                    'code': 'fixture_unavailable',
                    'message': 'Controlled unavailable response',
                  },
                }
              : {
                  'method': request.method,
                  'query': request.uri.queryParameters,
                  'body': body,
                },
        ),
      );
      final response = request.response
        ..statusCode = unavailable ? 503 : 200
        ..headers.contentType = ContentType.json
        ..contentLength = payload.length;
      if (request.uri.path == '/v1/held') {
        response
          ..bufferOutput = false
          ..add(payload.sublist(0, 4));
        await response.flush();
        await releaseHeld.future;
        response.add(payload.sublist(4));
      } else {
        response.add(payload);
      }
      await response.close();
    } on Object catch (error) {
      if (request.uri.path != '/v1/held' || !expectHeldCancellation) {
        errors.add(error);
      }
    }
  }

  Future<void> close() async {
    if (!releaseHeld.isCompleted) releaseHeld.complete();
    await server.close(force: true);
    await subscription.cancel();
    await Future.wait(handlers.toList());
  }
}
