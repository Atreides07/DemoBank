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
  'access-control-allow-headers': 'content-type, accept, accept-language',
  'access-control-expose-headers': 'content-length, content-language',
};

/// Texts in responses follow `Accept-Language` (`ru`, `en`, `uz`; Russian
/// otherwise), as the in-process simulator does.
Handler demoHandler(SimulatedTransport transport) => (Request request) async {
  if (request.method == 'OPTIONS') return Response(204, headers: _corsHeaders);
  final acceptLanguage = request.headers['accept-language'];
  final language = DemoTexts.negotiate(acceptLanguage);
  Response failure(int status, String code, String key) =>
      _failure(status, code, DemoTexts.text(language, key), language);
  final cancellation = SimulationCancellation();
  try {
    final bytes = await request.read().expand((chunk) => chunk).toList();
    if (bytes.length > 1024 * 1024) {
      return failure(413, 'body_too_large', 'error.bodyTooLarge');
    }
    final decoded = bytes.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      return failure(400, 'validation', 'error.jsonObject');
    }
    final exchange = await transport.open(
      SimulatedRequest(
        method: request.method,
        uri: request.requestedUri,
        body: Map<String, dynamic>.from(decoded),
        acceptLanguage: acceptLanguage,
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
        'content-language': language,
        'vary': 'accept-language',
      },
    );
  } on FormatException {
    return failure(400, 'validation', 'error.invalidJson');
  } on SimulatedTimeout {
    return failure(504, 'transport_timeout', 'error.timeout');
  } on SimulatedConnectionFailure {
    return failure(503, 'connection_unavailable', 'error.connection');
  } on SimulationCancelled {
    return failure(499, 'cancelled', 'error.cancelled');
  }
};

Response _failure(int status, String code, String message, String language) =>
    Response(
      status,
      body: jsonEncode({
        'error': {'code': code, 'message': message},
      }),
      headers: {
        ..._corsHeaders,
        'content-type': 'application/json; charset=utf-8',
        'content-language': language,
        'vary': 'accept-language',
      },
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
