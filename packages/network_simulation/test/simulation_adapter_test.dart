import 'dart:async';
import 'dart:convert';

import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:test/test.dart';

const _instant = NetworkProfile(
  name: 'test',
  firstByteLatency: Duration.zero,
  jitter: Duration.zero,
  bytesPerSecond: 1000000000,
  chunkBytes: 4096,
);

void main() {
  late DemoApi api;
  late ManualSimulationScheduler clock;
  late SimulationAdapter adapter;
  late ApiClient client;

  setUp(() async {
    api = DemoApi();
    await api.warmUp();
    clock = ManualSimulationScheduler();
    adapter = SimulationAdapter(api: api, scheduler: clock, profile: _instant);
    client = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: adapter,
    );
  });
  tearDown(() => client.close());

  test(
    'normal JSON serialization and parsing use the real client pipeline',
    () async {
      final pending = client.get('/v1/transactions', query: {'limit': 30});
      await clock.runUntilIdle();
      final page = await pending;
      expect((page['items'] as List).length, 30);
      expect(page['total'], 12000);
      expect(adapter.events.map((event) => event.phase), contains('completed'));
    },
  );

  test(
    'first byte and bandwidth are separately scheduled in real chunks',
    () async {
      final transport = SimulatedTransport(
        api: api,
        scheduler: clock,
        profile: const NetworkProfile(
          name: 'bandwidth-test',
          firstByteLatency: Duration(milliseconds: 100),
          jitter: Duration.zero,
          bytesPerSecond: 1000,
          chunkBytes: 50,
        ),
      );
      final response = transport.open(
        SimulatedRequest(
          method: 'GET',
          uri: Uri.parse('https://demo.invalid/v1/accounts'),
        ),
        SimulationCancellation(),
      );
      await clock.elapse(const Duration(milliseconds: 100));
      final exchange = await response;
      final received = <List<int>>[];
      final done = Completer<void>();
      final subscription = exchange.stream.listen(
        received.add,
        onDone: done.complete,
      );
      await clock.elapse(const Duration(milliseconds: 49));
      expect(received, isEmpty);
      await clock.elapse(const Duration(milliseconds: 1));
      expect(received.length, 1);
      expect(done.isCompleted, isFalse);
      await clock.runUntilIdle();
      await done.future;
      expect(received.length, greaterThan(1));
      expect(
        received.fold<int>(0, (sum, chunk) => sum + chunk.length),
        exchange.contentLength,
      );
      final body = jsonDecode(
        utf8.decode(received.expand((chunk) => chunk).toList()),
      );
      expect((body as Map)['revision'], '1');
      await subscription.cancel();
    },
  );

  test(
    'cancel before headers interrupts scheduled latency and logs cancellation',
    () async {
      adapter.profile = NetworkProfile.slow;
      final cancellation = RequestCancellation();
      final pending = client.get('/v1/accounts', cancellation: cancellation);
      final check = expectLater(
        pending,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      await clock.elapse(const Duration(milliseconds: 50));
      cancellation.cancel();
      await clock.elapse(Duration.zero);
      await check;
      expect(cancellation.isCancelled, isTrue);
      expect(adapter.events.last.phase, 'cancelled');
      expect(clock.pendingDelays, 0);
    },
  );

  test('cancel during gradual response interrupts bytes without decoded partial JSON', () async {
    adapter.profile = const NetworkProfile(
      name: 'cancel-stream',
      firstByteLatency: Duration.zero,
      jitter: Duration.zero,
      bytesPerSecond: 100,
      chunkBytes: 25,
    );
    final cancellation = RequestCancellation();
    final pending = client.get('/v1/accounts', cancellation: cancellation);
    final check = expectLater(
      pending,
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.cancelled,
        ),
      ),
    );
    await clock.elapse(const Duration(milliseconds: 300));
    expect(adapter.events.any((event) => event.phase == 'chunk'), isTrue);
    cancellation.cancel();
    await clock.elapse(Duration.zero);
    await check;
    expect(adapter.events.any((event) => event.phase == 'completed'), isFalse);
  });

  test(
    'separate request latencies produce genuinely out-of-order responses',
    () async {
      client.close();
      adapter = SimulationAdapter(
        api: api,
        scheduler: clock,
        profile: _instant,
        faults: const [
          FaultRule(path: '/accounts', latency: Duration(seconds: 2)),
          FaultRule(path: '/analytics', latency: Duration(milliseconds: 10)),
        ],
      );
      client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: adapter,
      );
      final order = <String>[];
      final accounts = client
          .get('/v1/accounts')
          .then((_) => order.add('accounts'));
      final analytics = client
          .get(
            '/v1/analytics',
            query: {'from': '2026-10-01', 'to': '2026-10-16'},
          )
          .then((_) => order.add('analytics'));
      await clock.elapse(const Duration(milliseconds: 500));
      expect(order, ['analytics']);
      await clock.runUntilIdle();
      await Future.wait([accounts, analytics]);
      expect(order, ['analytics', 'accounts']);
    },
  );

  test(
    'exact next-page HTTP failure succeeds on retry with the same cursor',
    () async {
      client.close();
      adapter = SimulationAdapter(
        api: api,
        scheduler: clock,
        profile: _instant,
        faults: const [
          FaultRule(
            path: '/transactions',
            nextPage: true,
            fault: SimulatedFault.httpError,
          ),
        ],
      );
      client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: adapter,
      );
      final firstFuture = client.get('/v1/transactions');
      await clock.runUntilIdle();
      final first = await firstFuture;
      final query = {'cursor': first['nextCursor']};
      final failed = client.get('/v1/transactions', query: query);
      final check = expectLater(
        failed,
        throwsA(
          isA<ApiFailure>().having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
      await clock.runUntilIdle();
      await check;
      final retried = client.get('/v1/transactions', query: query);
      await clock.runUntilIdle();
      final next = await retried;
      expect((next['items'] as List).length, 30);
      final oldIds = (first['items'] as List)
          .map((item) => (item as Map)['id'])
          .toSet();
      expect(
        (next['items'] as List).any(
          (item) => oldIds.contains((item as Map)['id']),
        ),
        isFalse,
      );
    },
  );

  test(
    'lost payment response commits once and is reconciled by the same key',
    () async {
      client.close();
      adapter = SimulationAdapter(
        api: api,
        scheduler: clock,
        profile: _instant,
        faults: const [
          FaultRule(
            path: '/checkout/payments',
            fault: SimulatedFault.lostResponse,
          ),
        ],
      );
      client = ApiClient(
        baseUri: Uri.parse('https://demo.invalid'),
        adapter: adapter,
      );
      final quoteFuture = client.post(
        '/checkout/quotes',
        data: {
          'kind': 'mobile',
          'referenceIds': <String>[],
          'amountMinor': 30000,
          'accountId': 'main',
          'recipient': 'МТС',
          'currency': 'RUB',
          'details': {'phone': '79991234567', 'operatorId': 'mts'},
        },
      );
      await clock.runUntilIdle();
      final quote = await quoteFuture;
      final data = {
        'quoteId': quote['id'],
        'idempotencyKey': 'lost-response-key',
      };
      final submit = client.post('/checkout/payments', data: data);
      final check = expectLater(
        submit,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.timeout,
          ),
        ),
      );
      await clock.runUntilIdle();
      await check;
      final statusFuture = client.get(
        '/checkout/payments/status',
        query: {'idempotencyKey': 'lost-response-key'},
      );
      await clock.runUntilIdle();
      final status = await statusFuture;
      expect(status['status'], 'succeeded');
      final repeat = client.post('/checkout/payments', data: data);
      await clock.runUntilIdle();
      expect((await repeat)['id'], status['id']);
      expect(api.revision, '2');
      expect(
        jsonEncode(adapter.events.map((event) => event.toJson()).toList()),
        isNot(contains('79991234567')),
      );
    },
  );

  test(
    'offline, timeout, and midstream disconnect are different fault events',
    () async {
      for (final fault in [
        SimulatedFault.offline,
        SimulatedFault.timeout,
        SimulatedFault.disconnect,
      ]) {
        final localAdapter = SimulationAdapter(
          api: api,
          scheduler: clock,
          profile: const NetworkProfile(
            name: 'fault-test',
            firstByteLatency: Duration.zero,
            jitter: Duration.zero,
            bytesPerSecond: 1000000000,
            chunkBytes: 16,
          ),
          faults: [FaultRule(path: '/accounts', fault: fault)],
        );
        final local = ApiClient(
          baseUri: Uri.parse('https://demo.invalid'),
          adapter: localAdapter,
        );
        final future = local.get('/accounts');
        final check = expectLater(
          future,
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.kind,
              'kind',
              fault == SimulatedFault.timeout
                  ? ApiFailureKind.timeout
                  : ApiFailureKind.offline,
            ),
          ),
        );
        await clock.runUntilIdle();
        await check;
        local.close();
      }
    },
  );
}
