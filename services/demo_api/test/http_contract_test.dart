import 'dart:io';

import 'package:demo_api/demo_api.dart';
import 'package:dio/io.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:test/test.dart';

const _fast = NetworkProfile(
  name: 'contract-test',
  firstByteLatency: Duration.zero,
  jitter: Duration.zero,
  bytesPerSecond: 1000000000,
  chunkBytes: 128,
);

void main() {
  test('real HTTP and local adapter have identical response/filter contracts', () async {
    final server = await startDemoServer(
      transport: SimulatedTransport(profile: _fast),
      port: 0,
    );
    final http = ApiClient(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    final local = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: SimulationAdapter(profile: _fast),
    );
    try {
      for (final path in [
        '/v1/accounts',
        '/v1/accounts/main/profile',
        '/v1/accounts/main/recipients',
        '/v1/transactions?from=2026-10-01&to=2026-10-16&kind=expense&limit=30',
        '/v1/analytics?from=2026-10-01&to=2026-10-16&accounts=main',
        '/services/fines?document=1234567890',
        '/services/utilities?account=12345678',
        '/services/operators?phone=79991234567',
        '/services/movies',
        '/services/sessions?movieId=movie-001',
        '/services/seats?sessionId=movie-001-evening',
      ]) {
        expect(await http.get(path), await local.get(path), reason: path);
      }
      const operation = {
        'requestId': 'http-account-contract',
        'kind': 'topUp',
        'amountMinor': 12345,
        'currency': 'RUB',
      };
      final result = await http.post(
        '/v1/accounts/main/operations',
        data: operation,
      );
      expect(
        await http.post('/v1/accounts/main/operations', data: operation),
        result,
      );
      expect(
        await local.post('/v1/accounts/main/operations', data: operation),
        result,
      );
      expect(await http.get('/v1/accounts'), await local.get('/v1/accounts'));
      const preferences = {'name': 'Учебный', 'roundUp': true};
      expect(
        await http.post('/v1/accounts/main/preferences', data: preferences),
        await local.post('/v1/accounts/main/preferences', data: preferences),
      );
      final raw = HttpClient();
      final options = await raw.openUrl(
        'OPTIONS',
        Uri.parse('http://127.0.0.1:${server.port}/v1/accounts'),
      );
      final preflight = await options.close();
      expect(preflight.statusCode, 204);
      expect(preflight.headers.value('access-control-allow-origin'), '*');
      await preflight.drain<void>();
      raw.close(force: true);
    } finally {
      http.close();
      local.close();
      await server.close(force: true);
    }
  });

  test('real HTTPS validates an explicitly trusted certificate and pays idempotently', () async {
    final directory = await Directory.systemTemp.createTemp('demobank-tls-');
    final cert = '${directory.path}/certificate.pem';
    final key = '${directory.path}/private-key.pem';
    final rootCert = '${directory.path}/root.pem';
    final rootKey = '${directory.path}/root-key.pem';
    final csr = '${directory.path}/server.csr';
    final extensions = '${directory.path}/extensions.cnf';
    await File(extensions).writeAsString(
      'subjectAltName=DNS:localhost,IP:127.0.0.1\n'
      'basicConstraints=critical,CA:FALSE\n'
      'keyUsage=critical,digitalSignature,keyEncipherment\n'
      'extendedKeyUsage=serverAuth\n',
    );
    Future<void> openssl(List<String> args) async {
      final result = await Process.run('openssl', args);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }

    await openssl([
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-sha256',
      '-days',
      '2',
      '-keyout',
      rootKey,
      '-out',
      rootCert,
      '-subj',
      '/CN=DemoBank Test CA',
      '-addext',
      'basicConstraints=critical,CA:TRUE',
      '-addext',
      'keyUsage=critical,keyCertSign,cRLSign',
    ]);
    await openssl([
      'req',
      '-new',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-sha256',
      '-keyout',
      key,
      '-out',
      csr,
      '-subj',
      '/CN=localhost',
    ]);
    await openssl([
      'x509',
      '-req',
      '-in',
      csr,
      '-CA',
      rootCert,
      '-CAkey',
      rootKey,
      '-CAcreateserial',
      '-out',
      cert,
      '-days',
      '1',
      '-sha256',
      '-extfile',
      extensions,
    ]);
    final serverContext = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
    final transport = SimulatedTransport(
      profile: _fast,
      faults: const [
        FaultRule(
          path: '/checkout/payments',
          fault: SimulatedFault.lostResponse,
        ),
      ],
    );
    final server = await startDemoServer(
      port: 0,
      securityContext: serverContext,
      transport: transport,
    );
    final clientContext = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificates(rootCert);
    final adapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(context: clientContext),
    );
    final client = ApiClient(
      baseUri: Uri.parse('https://127.0.0.1:${server.port}'),
      adapter: adapter,
    );
    try {
      final rawTls = HttpClient(context: clientContext);
      final rawRequest = await rawTls.getUrl(
        Uri.parse('https://127.0.0.1:${server.port}/health'),
      );
      final rawResponse = await rawRequest.close();
      expect(rawResponse.statusCode, 200);
      await rawResponse.drain<void>();
      rawTls.close(force: true);
      expect((await client.get('/health'))['status'], 'ok');
      final quote = await client.post(
        '/checkout/quotes',
        data: {
          'kind': 'fines',
          'referenceIds': ['fine-001'],
          'accountId': 'main',
          'recipient': 'Городская инспекция',
          'currency': 'RUB',
          'details': {
            'billVersions': {'fine-001': '1'},
          },
        },
      );
      final command = {
        'quoteId': quote['id'],
        'idempotencyKey': 'https-payment-001',
      };
      await expectLater(
        client.post('/checkout/payments', data: command),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.timeout,
          ),
        ),
      );
      final status = await client.get(
        '/checkout/payments/status',
        query: {'idempotencyKey': 'https-payment-001'},
      );
      expect(status['status'], 'succeeded');
      expect(
        (await client.post('/checkout/payments', data: command))['id'],
        status['id'],
      );
      expect(transport.api.revision, '2');
      final topup = {
        'requestId': 'https-account-topup',
        'kind': 'topUp',
        'amountMinor': 10001,
        'currency': 'RUB',
      };
      final accountResult = await client.post(
        '/v1/accounts/main/operations',
        data: topup,
      );
      expect(
        await client.post('/v1/accounts/main/operations', data: topup),
        accountResult,
      );
      expect((await client.get('/v1/accounts/main/profile'))['id'], 'main');
      expect(transport.api.revision, '3');
    } finally {
      client.close();
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  test('HTTP and local adapter answer in the requested language', () async {
    final server = await startDemoServer(
      transport: SimulatedTransport(profile: _fast),
      port: 0,
    );
    final http = ApiClient(
      baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      acceptLanguage: 'uz',
    );
    final local = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: SimulationAdapter(profile: _fast),
      acceptLanguage: 'uz',
    );
    try {
      for (final path in [
        '/v1/accounts',
        '/v1/transactions?limit=30&accounts=uzs&currency=UZS',
        '/services/movies',
      ]) {
        expect(await http.get(path), await local.get(path), reason: path);
      }
      final accounts = (await http.get('/v1/accounts'))['accounts'] as List;
      expect(
        accounts.map((account) => (account as Map)['name']),
        contains('Soʻm hisobi'),
      );
      http.acceptLanguage = 'en';
      final movies = (await http.get('/services/movies'))['items'] as List;
      expect((movies.first as Map)['title'], 'Orbit of Light');
    } finally {
      http.close();
      local.close();
      await server.close(force: true);
    }
  });
}
