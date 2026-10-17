import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:network_simulation/network_simulation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type, accept',
  'access-control-expose-headers': 'content-length',
};

Handler demoHandler(SimulatedTransport transport) => (Request request) async {
  if (request.method == 'OPTIONS') return Response(204, headers: _corsHeaders);
  final cancellation = SimulationCancellation();
  try {
    final bytes = await request.read().expand((chunk) => chunk).toList();
    if (bytes.length > 1024 * 1024) {
      return _failure(413, 'body_too_large', 'Слишком большой запрос');
    }
    final decoded = bytes.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      return _failure(400, 'validation', 'Ожидается JSON-объект');
    }
    final exchange = await transport.open(
      SimulatedRequest(
        method: request.method,
        uri: request.requestedUri,
        body: Map<String, dynamic>.from(decoded),
      ),
      cancellation,
    );
    final stream = Stream<Uint8List>.multi((controller) {
      final subscription = exchange.stream.listen(
        controller.addSync,
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
      controller.onCancel = () {
        cancellation.cancel();
        return subscription.cancel();
      };
    });
    return Response(
      exchange.statusCode,
      body: stream,
      headers: {
        ..._corsHeaders,
        'content-type': 'application/json; charset=utf-8',
        'content-length': '${exchange.contentLength}',
        'cache-control': 'no-store',
      },
    );
  } on FormatException {
    return _failure(400, 'validation', 'Некорректный JSON');
  } on SimulatedTimeout {
    return _failure(504, 'transport_timeout', 'Время ожидания ответа истекло');
  } on SimulatedConnectionFailure {
    return _failure(503, 'connection_unavailable', 'Соединение недоступно');
  } on SimulationCancelled {
    return _failure(499, 'cancelled', 'Запрос отменён');
  }
};

Response _failure(int status, String code, String message) => Response(
  status,
  body: jsonEncode({
    'error': {'code': code, 'message': message},
  }),
  headers: {..._corsHeaders, 'content-type': 'application/json; charset=utf-8'},
);

Future<HttpServer> startDemoServer({
  String host = '127.0.0.1',
  int port = 8080,
  SimulatedTransport? transport,
  SecurityContext? securityContext,
}) => shelf_io.serve(
  demoHandler(transport ?? SimulatedTransport()),
  host,
  port,
  securityContext: securityContext,
);
