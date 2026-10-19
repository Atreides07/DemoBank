import 'dart:async';

import 'package:bank_core/bank_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:network_client/network_client.dart';
import 'package:network_simulation/network_simulation.dart';
import 'package:spending_analytics/spending_analytics.dart';

Map<String, dynamic> summary(String currency) => {
  'currency': currency,
  'totalMinor': 0,
  'refundMinor': 0,
  'previousTotalMinor': 0,
  'count': 0,
  'revision': '1',
  'categories': <Object?>[],
  'merchants': <Object?>[],
  'timeline': <Object?>[],
  'comparisonFrom': '2026-09-01T00:00:00.000Z',
  'comparisonTo': '2026-10-01T00:00:00.000Z',
};

void main() {
  late ManualSimulationScheduler clock;
  late SimulationAdapter adapter;
  late ApiClient client;
  late MemoryCacheStore cache;
  late ApiAnalyticsRepository repository;
  var fail = false;
  Future<SimulatedResponse> Function(SimulatedRequest)? respond;
  setUp(() async {
    fail = false;
    respond = null;
    clock = ManualSimulationScheduler();
    adapter = SimulationAdapter(
      scheduler: clock,
      profile: const NetworkProfile(
        name: 'scopes',
        firstByteLatency: Duration(seconds: 1),
        jitter: Duration.zero,
        bytesPerSecond: 1000000000,
      ),
      api: DemoApi(
        routes: [
          (request) async {
            if (request.path != '/analytics') return null;
            if (respond != null) return respond!(request);
            return fail
                ? SimulatedResponse({
                    'error': {'code': 'unavailable', 'message': 'offline'},
                  }, statusCode: 503)
                : SimulatedResponse(
                    summary(request.query['currency'] ?? 'RUB'),
                  );
          },
        ],
      ),
    );
    client = ApiClient(
      baseUri: Uri.parse('https://demo.invalid'),
      adapter: adapter,
    );
    cache = MemoryCacheStore();
    repository = ApiAnalyticsRepository(client, cache);
    await adapter.api.warmUp();
  });
  tearDown(() async {
    client.close();
    await cache.close();
  });

  test('identical scopes share a request and one cancellation leaves the other alive', () async {
    final first = repository.createScope(), second = repository.createScope();
    final one = first.summary(LedgerFilter());
    final two = second.summary(LedgerFilter());
    await clock.elapse(Duration.zero);
    expect(adapter.events.where((e) => e.phase == 'started'), hasLength(1));
    first.cancelPending();
    await clock.runUntilIdle();
    expect(await one, same(await two));
    expect(adapter.events.where((e) => e.phase == 'cancelled'), isEmpty);
    expect(adapter.events.where((e) => e.phase == 'completed'), hasLength(1));
  });

  test(
    'rapid filter changes cancel unneeded requests and keep the latest result',
    () async {
      final cubit = AnalyticsCubit(repository, filter: LedgerFilter());
      addTearDown(cubit.close);
      final first = cubit.load(filter: LedgerFilter(category: 'groceries'));
      await clock.elapse(Duration.zero);
      final second = cubit.load(filter: LedgerFilter(category: 'dining'));
      await clock.elapse(Duration.zero);
      final third = cubit.load(filter: LedgerFilter(category: 'transport'));
      await clock.runUntilIdle();
      await Future.wait([first, second, third]);
      expect(adapter.events.where((e) => e.phase == 'cancelled'), hasLength(2));
      expect(adapter.events.where((e) => e.phase == 'completed'), hasLength(1));
      expect(cubit.state.filter.category, 'transport');
      expect(cubit.state.failed, isFalse);
    },
  );

  test('closing the last consumer cancels the pending request', () async {
    final cubit = AnalyticsCubit(repository, filter: LedgerFilter());
    final loading = cubit.load();
    await clock.elapse(Duration.zero);
    await cubit.close();
    await clock.runUntilIdle();
    await loading;
    expect(adapter.events.where((e) => e.phase == 'cancelled'), hasLength(1));
    expect(await repository.cached(LedgerFilter()), isNull);
  });

  test('language and currency never share requests', () async {
    final first = repository.summary(LedgerFilter());
    await clock.elapse(Duration.zero);
    client.acceptLanguage = 'en';
    final second = repository.summary(LedgerFilter());
    final third = repository.summary(LedgerFilter(currency: 'USD'));
    await clock.runUntilIdle();
    expect((await first).total.currency, 'RUB');
    expect((await second).total.currency, 'RUB');
    expect((await third).total.currency, 'USD');
    expect(adapter.events.where((e) => e.phase == 'started'), hasLength(3));
  });

  test('a data revision starts fresh work and retired responses do not overwrite its cache', () async {
    final pending = <Completer<SimulatedResponse>>[];
    respond = (_) {
      final gate = Completer<SimulatedResponse>();
      pending.add(gate);
      return gate.future;
    };
    final old = repository.createScope().summary(LedgerFilter());
    await clock.elapse(const Duration(seconds: 1));
    repository.invalidate();
    final fresh = repository.createScope().summary(LedgerFilter());
    await clock.elapse(const Duration(seconds: 1));
    expect(pending, hasLength(2));
    pending[1].complete(
      SimulatedResponse({...summary('RUB'), 'revision': '2'}),
    );
    await clock.runUntilIdle();
    await fresh;
    pending[0].complete(
      SimulatedResponse({...summary('RUB'), 'revision': '1'}),
    );
    await clock.runUntilIdle();
    await old;
    expect((await repository.cached(LedgerFilter()))!.revision, '2');
  });

  test(
    'failed shared requests are released so retry starts a new request',
    () async {
      fail = true;
      final loading = repository.summary(LedgerFilter());
      final failed = expectLater(loading, throwsA(isA<ApiFailure>()));
      await clock.runUntilIdle();
      await failed;
      fail = false;
      final retry = repository.summary(LedgerFilter());
      await clock.runUntilIdle();
      await retry;
      expect(adapter.events.where((e) => e.phase == 'started'), hasLength(2));
    },
  );
}
